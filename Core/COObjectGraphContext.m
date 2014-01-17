/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  July 2013
	License:  MIT  (see COPYING)
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
#import "COBranch+Private.h"
#import "COItem.h"
#import "CODictionary.h"

NSString * const COObjectGraphContextObjectsDidChangeNotification = @"COObjectGraphContextObjectsDidChangeNotification";

NSString * const COInsertedObjectsKey = @"COInsertedObjectsKey";
NSString * const COUpdatedObjectsKey = @"COUpdatedObjectsKey";
NSString * const COObjectGraphContextWillRelinquishObjectsNotification = @"COObjectGraphContextWillRelinquishObjectsNotification";
NSString * const CORelinquishedObjectsKey = @"CORelinquishedObjectsKey";

NSString * const COObjectGraphContextBeginBatchChangeNotification = @"COObjectGraphContextBeginBatchChangeNotification";
NSString * const COObjectGraphContextEndBatchChangeNotification = @"COObjectGraphContextEndBatchChangeNotification";


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

@synthesize modelDescriptionRepository = _modelDescriptionRepository;
@synthesize insertedObjectUUIDs = _insertedObjectUUIDs;
@synthesize updatedObjectUUIDs = _updatedObjectUUIDs;

#pragma mark Creation

- (id)initWithBranch: (COBranch *)aBranch
     modelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
{
    SUPERINIT;
    _loadedObjects = [[NSMutableDictionary alloc] init];
	_objectsByAdditionalItemUUIDs = [[NSMutableDictionary alloc] init];
    _insertedObjectUUIDs = [[NSMutableSet alloc] init];
    _updatedObjectUUIDs = [[NSMutableSet alloc] init];
    _updatedPropertiesByUUID = [[NSMutableDictionary alloc] init];
    _branch = aBranch;
	_persistentRoot = [aBranch persistentRoot];
	_futureBranchUUID = (aBranch == nil ? [ETUUID UUID] : nil);
    if (aRepo == nil)
    {
        aRepo = [[_persistentRoot editingContext] modelDescriptionRepository];
    }
    _modelDescriptionRepository =  aRepo;
    return self;
}

- (id)initWithBranch: (COBranch *)aBranch
{
    return [self initWithBranch: aBranch modelDescriptionRepository: nil];
}

- (id)initWithModelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
{
    return [self initWithBranch: nil modelDescriptionRepository: aRepo];
}

- (id)init
{
    return [self initWithModelDescriptionRepository: [ETModelDescriptionRepository mainRepository]];
}

+ (COObjectGraphContext *)objectGraphContext
{
    return [[self alloc] init];
}

+ (COObjectGraphContext *)objectGraphContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
{
    return [[self alloc] initWithModelDescriptionRepository: aRepo];
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"<%@: %p - %@ - rootObject: %@>",
		NSStringFromClass([self class]), self, [self branchUUID], [self rootItemUUID]];
}

- (NSString *)detailedDescription
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

- (COBranch *)branch
{
	if (_branch == nil && _persistentRoot != nil)
	{
		return [_persistentRoot currentBranch];
	}
	return _branch;
}

- (void)setBranch: (COBranch *)aBranch
{
	_branch = aBranch;
	_persistentRoot = [aBranch persistentRoot];
}

- (ETUUID *)branchUUID
{
	return ([self branch] != nil ? [[self branch] UUID] : _futureBranchUUID);
}

- (COPersistentRoot *)persistentRoot
{
    return _persistentRoot;
}

- (void)setPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
	_persistentRoot = aPersistentRoot;
	_branch = nil;
}

- (COEditingContext *)editingContext
{
    return [_persistentRoot parentContext];
}

- (BOOL) isTrackingSpecificBranch
{
	return [self persistentRoot] != nil && self != [[self persistentRoot] objectGraphContext];
}

#pragma mark -
#pragma mark Metamodel Access

+ (NSString *)entityNameForItem: (COItem *)anItem
{
    return [anItem valueForAttribute: kCOObjectEntityNameProperty];
}

// NOTE: If we decide to make the method public, move it to COEditingContext
+ (NSString *)defaultEntityName
{
	return @"COObject";
}

+ (ETEntityDescription *)descriptionForItem: (COItem *)anItem
				 modelDescriptionRepository: (ETModelDescriptionRepository *)aRepository
{
    NSString *name = [self entityNameForItem: anItem];
    
    if (name == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"COItem %@ lacks an entity name", anItem];
    }
    
	ETEntityDescription *desc = [aRepository descriptionForName: name];
    
    if (desc == nil)
    {
        desc = [aRepository descriptionForName: [self defaultEntityName]];
    }
    
    return desc;
}

- (ETEntityDescription *)descriptionForItem: (COItem *)anItem
{
	return [[self class] descriptionForItem: anItem modelDescriptionRepository: _modelDescriptionRepository];
}

#pragma mark -
#pragma mark Loading Objects

- (id)objectWithUUID: (ETUUID *)aUUID
   entityDescription: (ETEntityDescription *)anEntityDescription
{
	Class objClass = [_modelDescriptionRepository classForEntityDescription: anEntityDescription];
	/* For a reloaded object, we must not call -initWithEntityDescription:objectGraphContext:
	   to prevent the normal initialization process to occur (the COObject
	   subclass designed initializer being called). */
	COObject *obj = [[objClass alloc] prepareWithUUID: aUUID
                                    entityDescription: anEntityDescription
	                               objectGraphContext: self
	                                            isNew: NO];
	
	[_loadedObjects setObject: obj forKey: aUUID];
	
	return obj;
}

- (id)objectReferenceWithUUID: (ETUUID *)aUUID
{
    ETAssert(_loadingItemGraph != nil);
	
	COObject *loadedObject = [_loadedObjects objectForKey: aUUID];

	if (loadedObject != nil)
		return loadedObject;
    
	COItem *item = [_loadingItemGraph itemForUUID: aUUID];
    if (item == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Couldn't resolve reference to object %@", aUUID];
    }
	
	/* The metamodel cannot be used for the entity description because the 
	   loaded object type could be a subtype of the type declared in the 
	   metamodel. For example, a to-one relationship of type COObject could 
	   point a COBookmark object, so allocating a COObject as declared in the 
	   metamodel doesn't give us the right object. */
	return [self objectWithUUID: aUUID
	          entityDescription: [self descriptionForItem: item]];
}

- (COObject *)objectWithStoreItem: (COItem *)anItem
{
	NILARG_EXCEPTION_TEST(anItem);
    
	COObject *obj = [self objectWithUUID: [anItem UUID]
	                   entityDescription: [self descriptionForItem: anItem]];

    [obj setStoreItem: anItem];

	return obj;
}

- (id <COItemGraph>)loadingItemGraph
{
	return _loadingItemGraph;
}

/**
 * Sends -didLoadObjectGraph to the objects just deserialized from the given 
 * items.
 *
 * The root object (if deserialized), is the last object to receive 
 * -didLoadObjectGraph.
 */
- (void)finishLoadingObjectsWithUUIDs: (NSArray *)itemUUIDs
{
	for (ETUUID *UUID in itemUUIDs)
	{
		// NOTE: Based on the assumption, the root object UUID remains the same
		BOOL isRootObject = [[self rootItemUUID] isEqual: UUID];

		if (isRootObject)
			continue;
		
		COObject *object = [self loadedObjectForUUID: UUID];
		// TODO: Don't include the additional item UUIDs in the UUIDs argument
		ETAssert(object != nil || [[_loadingItemGraph itemForUUID: UUID] isAdditionalItem]);

		[object didLoadObjectGraph];
	}

	BOOL wasRootObjectDeserialized = [itemUUIDs containsObject: [self rootItemUUID]];

	if (wasRootObjectDeserialized)
	{
		[[self rootObject] didLoadObjectGraph];
	}
}

#pragma mark -
#pragma mark Item Graph Protocol

- (ETUUID *)rootItemUUID
{
    return _rootObjectUUID;
}

- (COItem *)itemForUUID: (ETUUID *)aUUID
{
    COObject *object = [_loadedObjects objectForKey: aUUID];
	
	if (object != nil)
		return [object storeItem];

	return [[_objectsByAdditionalItemUUIDs objectForKey: aUUID] additionalStoreItemForUUID: aUUID];
}

- (NSArray *)itemUUIDs
{
    NSArray *additionalItemUUIDs = [_objectsByAdditionalItemUUIDs allKeys];

	return [[_loadedObjects allKeys] arrayByAddingObjectsFromArray: additionalItemUUIDs];
}

/**
 * Caller must handle marking the item as inserted/updated, if desired.
 * Note that this may call itself recursively
 */
- (void)addItem: (COItem *)item
{
    NSParameterAssert(item != nil);

	/* Additional items are deserialized by their owner object deserialization */
	if ([item isAdditionalItem])
		return;
    
    ETUUID *uuid = [item UUID];
    COObject *currentObject = [_loadedObjects objectForKey: uuid];
    
    if (currentObject == nil)
    {
        currentObject = [self objectWithStoreItem: item];
    }
    else
    {
        [currentObject setStoreItem: item];
    }

	for (ETUUID *itemUUID in [[currentObject additionalStoreItemUUIDs] objectEnumerator])
	{
		[_objectsByAdditionalItemUUIDs setObject: currentObject forKey: itemUUID];
	}
	ETAssert([[_objectsByAdditionalItemUUIDs allKeys] containsCollection: [[currentObject additionalStoreItemUUIDs] allValues]]);
}

- (void)insertOrUpdateItems: (NSArray *)items
{
    if ([items count] == 0)
        return;

	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextBeginBatchChangeNotification
														object: self];
	
	// Update change tracking
	for (COItem *item in items)
	{
		if ([_loadedObjects objectForKey: item.UUID] != nil)
		{
			// TODO: Check it the item is actually different?
			[_updatedObjectUUIDs addObject: item.UUID];
		}
		else
		{
			[_insertedObjectUUIDs addObject: item.UUID];
		}
	}
    
    // Wrap the items array in a COItemGraph, so they can be located by
    // -objectReferenceWithUUID:. The rootItemUUID is ignored.
    _loadingItemGraph = [[COItemGraph alloc] initWithItems: items
                                              rootItemUUID: [[items objectAtIndex: 0] UUID]];
    
    for (COItem *item in items)
    {
        [self addItem: item];
    }
	[self finishLoadingObjectsWithUUIDs: [_loadingItemGraph itemUUIDs]];
	
	_loadingItemGraph = nil;
	
	// NOTE: -acceptAllChanges *not* called
	
	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextEndBatchChangeNotification
														object: self];
}

- (void)setItemGraph: (id <COItemGraph>)aTree
{
	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextBeginBatchChangeNotification
														object: self];
	
	NSParameterAssert(aTree != nil);
	
	// i.e., the root object can be set once and never changed.
	NSParameterAssert(_rootObjectUUID == nil || [_rootObjectUUID isEqual: [aTree rootItemUUID]]);
    _rootObjectUUID =  [aTree rootItemUUID];
    
	// Update change tracking
	for (ETUUID *itemUUID in [aTree itemUUIDs])
	{
		if ([_loadedObjects objectForKey: itemUUID] != nil)
		{
			// TODO: Check it the item is actually different?
			[_updatedObjectUUIDs addObject: itemUUID];
		}
		else
		{
			[_insertedObjectUUIDs addObject: itemUUID];
		}
	}
	
	// NOTE: To prevent caching the item graph during the loading, a better
	// approach could be to allocate all the objects before loading them.
	// We could also change -[COObjectGraphContext itemForUUID:] to search aTree
	// during the loading rather than the loaded objects (but that's roughly the
	// same than we do currently).
	_loadingItemGraph = aTree;

    for (ETUUID *uuid in [aTree itemUUIDs])
    {
        [self addItem: [aTree itemForUUID: uuid]];
    }
	[self finishLoadingObjectsWithUUIDs: [aTree itemUUIDs]];

	_loadingItemGraph = nil;
    
    // Clear change tracking
    
    [self acceptAllChanges];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextEndBatchChangeNotification
														object: self];
}

#pragma mark -
#pragma mark Accessing the Root Object

- (id)rootObject
{
	/* To support -rootObject access during the root object instantiation */
	if ([self rootItemUUID] == nil)
		return nil;

    return [self loadedObjectForUUID: [self rootItemUUID]];
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
		[_insertedObjectUUIDs addObject: uuid];
		
		for (ETUUID *itemUUID in [[object additionalStoreItemUUIDs] objectEnumerator])
		{
			[_objectsByAdditionalItemUUIDs setObject: object forKey: itemUUID];
		}
	}
}

#pragma mark -
#pragma mark Change Tracking

- (NSSet *)changedObjectUUIDs
{
    return [_insertedObjectUUIDs setByAddingObjectsFromSet: _updatedObjectUUIDs];
}

- (BOOL)isUpdatedObject: (COObject *)anObject
{
    return [_updatedObjectUUIDs containsObject: anObject.UUID];
}

- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty
{
	ETUUID *uuid = obj.UUID;
	if (nil == [_updatedPropertiesByUUID objectForKey: uuid])
	{
		_updatedPropertiesByUUID[uuid] = [NSMutableArray array];
	}
	if (aProperty != nil)
	{
		ETAssert([aProperty isKindOfClass: [NSString class]]);
		[_updatedPropertiesByUUID[uuid] addObject: aProperty];
	}
    
    // If it's already marked as inserted, don't mark it as updated
    if (![_insertedObjectUUIDs containsObject: uuid])
    {
        [_updatedObjectUUIDs addObject: uuid];
    }
}
   
- (BOOL)hasChanges
{
	return [_updatedObjectUUIDs count] > 0
		|| [_insertedObjectUUIDs count] > 0;
}
   
- (void)discardAllChanges
{
	if ([self branch] == nil)
	{
		[self discardObjectsWithUUIDs: [NSSet setWithArray: [_loadedObjects allKeys]]];
		[self acceptAllChanges];
		ETAssert([[self loadedObjects] isEmpty]);
	}
	else
	{
		[[self branch] reloadAtRevision: [[self branch] currentRevision]];
	}
}

/**
 * Posts COObjectGraphContextWillRelinquishObjectsNotification
 */
- (void)discardObjectsWithUUIDs: (NSSet *)objectUUIDs
{
	NSMutableArray *objectsToDiscard = [NSMutableArray new];
	for (ETUUID *uuid in objectUUIDs)
	{
		COObject *obj = [self loadedObjectForUUID: uuid];
		[objectsToDiscard addObject: obj];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextWillRelinquishObjectsNotification
														object: self
													  userInfo: @{ CORelinquishedObjectsKey : objectsToDiscard} ];
	
	for (COObject *objectToDiscard in objectsToDiscard)
	{
		[self discardObject: objectToDiscard];
	}
}

/**
 * Caller must post COObjectGraphContextWillRelinquishObjectsNotification
 */
- (void)discardObject: (COObject *)anObject
{
	ETUUID *uuid = [anObject UUID];
	
    // Mark the object as a "zombie"
    
    [anObject markAsRemovedFromContext];
	
	// Update change tracking
    
    [_insertedObjectUUIDs removeObject: uuid];
    [_updatedObjectUUIDs removeObject: uuid];

	// Remove it from the additional item to object lookup table

	[_objectsByAdditionalItemUUIDs removeObjectsForKeys: [[anObject additionalStoreItemUUIDs] allValues]];
    
    // Release it from the objects dictionary (may release it)
    
    [_loadedObjects removeObjectForKey: uuid];
}

- (void)acceptAllChanges
{
	NSSet *insertedObjects = [_insertedObjectUUIDs copy];
	NSSet *updatedObjects = [_updatedObjectUUIDs copy];
	
    [_insertedObjectUUIDs removeAllObjects];
    [_updatedObjectUUIDs removeAllObjects];
    [_updatedPropertiesByUUID removeAllObjects];
			
    [[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextObjectsDidChangeNotification
                                                        object: self
													  userInfo: @{ COInsertedObjectsKey : insertedObjects,
																   COUpdatedObjectsKey : updatedObjects }];
}

- (NSArray *)insertedObjects
{
	return [self loadedObjectsForUUIDs: [_insertedObjectUUIDs allObjects]];
}

- (NSArray *)updatedObjects
{
	return [self loadedObjectsForUUIDs: [_updatedObjectUUIDs allObjects]];
}

- (NSArray *)changedObjects
{
	return [self loadedObjectsForUUIDs: [[self changedObjectUUIDs] allObjects]];
}

- (NSDictionary *)updatedPropertiesByUUID
{
	return _updatedPropertiesByUUID;
}

#pragma mark -
#pragma mark Accessing Loaded Objects

- (NSArray *)loadedObjects
{
    return [_loadedObjects allValues];
}

- (COObject *)loadedObjectForUUID: (ETUUID *)aUUID
{
	// NOTE: We serialize UUIDs into strings in various places, this check
	// helps to intercept string objects that ought to be ETUUID objects.
	NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
    COObject *obj = [_loadedObjects objectForKey: aUUID];
	ETAssert(obj == nil || [obj isKindOfClass: [COObject class]]);
	return obj;
}

- (NSArray *)loadedObjectsForUUIDs: (NSArray *)UUIDs
{
	NSMutableArray *objects = [NSMutableArray arrayWithCapacity: [UUIDs count]];

	for (ETUUID *UUID in UUIDs)
	{
		[objects addObject: [self loadedObjectForUUID: UUID]];
	}
	return objects;
}


#pragma mark -
#pragma mark Garbage Collection

- (void)removeUnreachableObjects
{
    if ([self rootObject] == nil)
    {
        return;
    }
    
    NSMutableSet *deadUUIDs = [NSMutableSet setWithArray: [_loadedObjects allKeys]];
	NSSet *liveUUIDs = [self allReachableObjectUUIDs];
    [deadUUIDs minusSet: liveUUIDs];
    
	// FIXME: Should the other places that call -discardObjectsWithUUIDs: also do this?
    for (ETUUID *deadUUID in deadUUIDs)
    {
		COObject *anObject = [_loadedObjects objectForKey: deadUUID];
		[anObject removeCachedOutgoingRelationships];
    }
	
	[self discardObjectsWithUUIDs: deadUUIDs];
}

- (void)replaceObject: (COObject *)anObject withObject: (COObject *)aReplacement
{
	for (COObject *referrer in [[anObject incomingRelationshipCache] referringObjects])
	{
		[referrer replaceReferencesToObjectIdenticalTo: anObject
											withObject: aReplacement];
	}
}

@end
