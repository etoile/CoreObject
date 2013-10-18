/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COObjectGraphContext.h"
#import "COItemGraph.h"
#import "COObjectGraphContext+GarbageCollection.h"
#import "CORelationshipCache.h"
#import "COObject+Private.h"
#import "COObject+RelationshipCache.h"
#import "COSerialization.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COItem.h"
#import "CODictionary.h"

NSString * const COObjectGraphContextObjectsDidChangeNotification = @"COObjectGraphContextObjectsDidChangeNotification";

/**
 * COEditingContext semantics:
 *
 * A mutable view on a set of COItem objects which materializes the relationships
 * as actual ObjC object references.
 *
 * The main feature is that the underlying objects can be changed arbitrairly and
 * the view will update accordingly.
 *
 * The COItems are garbage collected. See discussion in COItemTree.h.
 * The main motivation is to avoid having to store semantically redundant
 * "explicit delete" operations in diffs.
 *
 * Garbage collection shouldn't need to be invoked by the user. It happens
 * at commit time, and when loading a new object graph.
 *
 * TODO: Fit in change notifications
 *
 * Behaviours:
 *  - record which objects were edited/inserted
 *  - maintain consistency of composite relationship, for edits
 *    made through the COObject api (but not through -insertOrUpdateItems: api)
 *  - maintain relationship cache, for all edits
 *  - post notifications
 */
@implementation COObjectGraphContext

@synthesize branch = _branch, modelRepository = _modelRepository;
@synthesize insertedObjects = _insertedObjects, updatedObjects = _updatedObjects,
	updatedPropertiesByObject = _updatedPropertiesByObject;

#pragma mark Creation

- (id)initWithBranch: (COBranch *)aBranch
     modelRepository: (ETModelDescriptionRepository *)aRepo
{
    SUPERINIT;
    _loadedObjects = [[NSMutableDictionary alloc] init];
    _insertedObjects = [[NSMutableSet alloc] init];
    _updatedObjects = [[NSMutableSet alloc] init];
    _updatedPropertiesByObject = [[NSMapTable alloc] init];
    _branch = aBranch;
    if (aRepo == nil)
    {
        aRepo = [[[_branch persistentRoot] editingContext] modelRepository];
    }
    _modelRepository =  aRepo;
    return self;
}

- (id)initWithBranch: (COBranch *)aBranch
{
    return [self initWithBranch: aBranch modelRepository: nil];
}

- (id)initWithModelRepository: (ETModelDescriptionRepository *)aRepo
{
    return [self initWithBranch: nil modelRepository: aRepo];
}

- (id)init
{
    return [self initWithModelRepository: [ETModelDescriptionRepository mainRepository]];
}

+ (COObjectGraphContext *)objectGraphContext
{
    return [[self alloc] init];
}

+ (COObjectGraphContext *)objectGraphContextWithModelRepository: (ETModelDescriptionRepository *)aRepo
{
    return [[self alloc] initWithModelRepository: aRepo];
}


- (NSString *)description
{
	NSMutableString *result = [NSMutableString string];
    
	[result appendFormat: @"[COObjectGraphContext root: %@\n", [self rootItemUUID]];
	for (ETUUID *uuid in [self itemUUIDs])
	{
        COItem *item = [self itemForUUID: uuid];
		[result appendFormat: @"%@", item];
	}
	[result appendFormat: @"]"];
	
	return result;
}

- (BOOL)isObjectGraphContext
{
	return YES;
}

#pragma mark -
#pragma mark Related Persistency Management Objects

- (void)setBranch: (COBranch *)aBranch
{
	_branch = aBranch;
}

- (COPersistentRoot *)persistentRoot
{
    return [_branch persistentRoot];
}

- (COEditingContext *)editingContext
{
    return [[_branch persistentRoot] parentContext];
}

#pragma mark -
#pragma mark Metamodel Access

- (NSString *)entityNameForItem: (COItem *)anItem
{
    return [anItem valueForAttribute: kCOObjectEntityNameProperty];
}

// NOTE: If we decide to make the method public, move it to COEditingContext
- (NSString *)defaultEntityName
{
	return @"COObject";
}

- (ETEntityDescription *)descriptionForItem: (COItem *)anItem
{
    NSString *name = [self entityNameForItem: anItem];
    
    if (name == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"COItem %@ lacks an entity name", anItem];
    }
    
	ETEntityDescription *desc = [_modelRepository descriptionForName: name];
    
    if (desc == nil)
    {
        desc = [_modelRepository descriptionForName: [self defaultEntityName]];
    }
    
    return desc;
}

#pragma mark -
#pragma mark Loading Objects

- (id)objectWithUUID: (ETUUID *)aUUID
   entityDescription: (ETEntityDescription *)anEntityDescription
{
	Class objClass = [_modelRepository classForEntityDescription: anEntityDescription];
	/* For a reloaded object, we must no call -initWithUUID:entityDescription:context:
	   to prevent the normal initialization process to occur (the COObject
	   subclass designed initializer being called). */
	COObject *obj = [[objClass alloc] commonInitWithUUID: aUUID
                                       entityDescription: anEntityDescription
	                                  objectGraphContext: self
	                                               isNew: NO];
	
	[_loadedObjects setObject: obj forKey: aUUID];
	
	return obj;
}

- (id)objectReferenceWithUUID: (ETUUID *)aUUID
{
	COObject *loadedObject = [_loadedObjects objectForKey: aUUID];

	if (loadedObject != nil)
		return loadedObject;

    // FIXME: This assertion was moved from the top of the function because
    // the cross-persistent root reference code uses -objectReferenceWithUUID:
    // directly without setting _loadingItemGraph. It probably shouldn't,
    // re-evaluate.
    ETAssert(_loadingItemGraph != nil);
    
	/* The metamodel cannot be used for the entity description because the 
	   loaded object type could be a subtype of the type declared in the 
	   metamodel. For example, a to-one relationship of type COObject could 
	   point a COBookmark object, so allocating a COObject as declared in the 
	   metamodel doesn't give us the right object. */
	return [self objectWithUUID: aUUID
	          entityDescription: [self descriptionForItem: [_loadingItemGraph itemForUUID: aUUID]]];
}

- (COObject *)objectWithStoreItem: (COItem *)anItem
{
	NILARG_EXCEPTION_TEST(anItem);
    
	COObject *obj = [self objectWithUUID: [anItem UUID]
	                   entityDescription: [self descriptionForItem: anItem]];

    [obj setStoreItem: anItem];

	return obj;
}

#pragma mark -
#pragma mark Item Graph Protocol

- (ETUUID *)rootItemUUID
{
    return _rootObjectUUID;
}

- (COItem *)itemForUUID: (ETUUID *)aUUID
{
    return [[_loadedObjects objectForKey: aUUID] storeItem];
}

- (NSArray *)itemUUIDs
{
    return [_loadedObjects allKeys];
}

- (void)addItem: (COItem *)item markAsInserted: (BOOL)markInserted
{
    NSParameterAssert(item != nil);
    
    ETUUID *uuid = [item UUID];
    COObject *currentObject = [_loadedObjects objectForKey: uuid];
    
    if (currentObject == nil)
    {
        currentObject = [self objectWithStoreItem: item];
        if (markInserted)
        {
            [_insertedObjects addObject: currentObject];
        }
    }
    else
    {
        [currentObject setStoreItem: item];
        [_updatedObjects addObject: currentObject];
    }
}

- (void) insertOrUpdateItems: (NSArray *)items
{
    if ([items count] == 0)
        return;
    
    // Wrap the items array in a COItemGraph, so they can be located by
    // -objectReferenceWithUUID:. The rootItemUUID is ignored.
    _loadingItemGraph = [[COItemGraph alloc] initWithItems: items
                                              rootItemUUID: [[items objectAtIndex: 0] UUID]];
    
    for (COItem *item in items)
    {
        [self addItem: item markAsInserted: NO];
    }
	
	_loadingItemGraph = nil;
}

- (void)setItemGraph: (id <COItemGraph>)aTree
{
	[self discardObjects: [self insertedObjects]];
    [self clearChangeTracking];

    // 1. Do updates.

    _rootObjectUUID =  [aTree rootItemUUID];
    
	// TODO: To prevent caching the item graph during the loading, a better
	// approach could be to allocate all the objects before loading them.
	// We could also change -[COObjectGraphContext itemForUUID:] to search aTree
	// during the loading rather than the loaded objects (but that's roughly the
	// same than we do currently).
	_loadingItemGraph =  aTree;

    for (ETUUID *uuid in [aTree itemUUIDs])
    {
        [self addItem: [aTree itemForUUID: uuid] markAsInserted: NO];
    }
	
	_loadingItemGraph = nil;
    
    // 3. Do GC
    
    [self removeUnreachableObjects];
    
    // 4. Clear change tracking again.
    
    [self clearChangeTracking];
}

#pragma mark -
#pragma mark Accessing the Root Object

- (id)rootObject
{
	/* To support -rootObject access during the root object instantiation */
	if ([self rootItemUUID] == nil)
		return nil;

    return [self objectWithUUID: [self rootItemUUID]];
}

- (void)setRootObject: (COObject *)anObject
{
    NSParameterAssert([anObject objectGraphContext] == self);
	// i.e., the root object can be set once and never changed.
	NSParameterAssert(_rootObjectUUID == nil || [_rootObjectUUID isEqual: [anObject UUID]]);
	
    _rootObjectUUID =  [anObject UUID];
}

#pragma mark -
#pragma mark Object Insertion

- (void)registerObject: (COObject *)object isNew: (BOOL)inserted
{
	NILARG_EXCEPTION_TEST(object);
	INVALIDARG_EXCEPTION_TEST(object, [object isKindOfClass: [COObject class]]);

    ETUUID *uuid = [object UUID];
    
	INVALIDARG_EXCEPTION_TEST(object, [_loadedObjects objectForKey: uuid] == nil);
    
    [_loadedObjects setObject: object forKey: uuid];
	if (inserted)
	{
		[_insertedObjects addObject: object];
	}
}

#pragma mark -
#pragma mark Change Tracking

- (NSSet *)changedObjects
{
    return [_insertedObjects setByAddingObjectsFromSet: _updatedObjects];
}
   
- (BOOL)isUpdatedObject: (COObject *)anObject
{
    return [_updatedObjects containsObject: anObject];
}

- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty
{
	if (nil == [_updatedPropertiesByObject objectForKey: obj])
	{
		[_updatedPropertiesByObject setObject: [NSMutableArray array] forKey: obj];
	}
	if (aProperty != nil)
	{
		ETAssert([aProperty isKindOfClass: [NSString class]]);
		[[_updatedPropertiesByObject objectForKey: obj] addObject: aProperty];
	}
    
    // If it's already marked as inserted, don't mark it as updated
    if (![_insertedObjects containsObject: obj])
    {
        [_updatedObjects addObject: obj];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextObjectsDidChangeNotification
                                                        object: self];
}
   
- (BOOL)hasChanges
{
	return [[self changedObjects] count] > 0;
}
   
- (void)discardAllChanges
{
	if ([self branch] == nil)
	{
		[self discardObjects: [self insertedObjects]];
		[self clearChangeTracking];
		ETAssert([[self loadedObjects] isEmpty]);
	}
	else
	{
		[[self branch] reloadAtRevision: [[self branch] currentRevision]];
	}
}

- (void)discardObjects: (NSSet *)objects
{
	[_loadedObjects removeObjectsForKeys: [(id)[[objects mappedCollection] UUID] allObjects]];
}

- (void) clearChangeTracking
{
    [_insertedObjects removeAllObjects];
    [_updatedObjects removeAllObjects];
    [_updatedPropertiesByObject removeAllObjects];
}

#pragma mark -
#pragma mark Accessing Loaded Objects

- (NSSet *)loadedObjects
{
    return [NSSet setWithArray: [_loadedObjects allValues]];
}

- (COObject *) objectWithUUID: (ETUUID *)aUUID
{
	// NOTE: We serialize UUIDs into strings in various places, this check
	// helps to intercept string objects that ought to be ETUUID objects.
	NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
    COObject *obj = [_loadedObjects objectForKey: aUUID];
	ETAssert(obj == nil || [obj isKindOfClass: [COObject class]]);
	return obj;
}

#pragma mark -
#pragma mark Garbage Collection

/**
 * Call to update the view to reflect one object becoming unavailable.
 *
 * Preconditions:
 *  - No objects in the context should have composite relationsips
 *    to uuid.
 *
 * Postconditions:
 *  - objectForUUID: will return nil
 *  - the COObject previously held by the context will be turned into a "zombie"
 *    and the COEditingContext will release it, so it will be deallocated if
 *    no user code holds a reference to it.
 */
- (void) removeSingleObjectWithUUID: (ETUUID *)uuid
{
    COObject *anObject = [_loadedObjects objectForKey: uuid];
    
    // Update relationship cache
    
    [anObject removeCachedOutgoingRelationships];
    
    // Update change tracking
    
    [_insertedObjects removeObject: anObject];
    [_updatedObjects removeObject: anObject];
    
    // Mark the object as a "zombie"
    
    [anObject markAsRemovedFromContext];
    
    // Release it from the objects dictionary (may release it)
    
    [_loadedObjects removeObjectForKey: uuid];
    anObject = nil;
}

- (void) removeUnreachableObjects
{
    if ([self rootObject] == nil)
    {
        return;
    }
    
    NSMutableSet *deadUUIDs = [NSMutableSet setWithArray: [_loadedObjects allKeys]];
	NSSet *liveUUIDs = [self allReachableObjectUUIDs];
    [deadUUIDs minusSet: liveUUIDs];
    
    for (ETUUID *deadUUID in deadUUIDs)
    {
        [self removeSingleObjectWithUUID: deadUUID];
    }
}

@end
