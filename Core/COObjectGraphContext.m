#import "COObjectGraphContext.h"
#import "COItemGraph.h"
#import "CORelationshipCache.h"
#import "COObject+RelationshipCache.h"
#import "COSerialization.h"
#import "COPersistentRoot.h"
#import "COBranch.h"

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

#pragma mark Creation

- (id) initWithBranch: (COBranch *)aBranch
      modelRepository: (ETModelDescriptionRepository *)aRepo
{
    SUPERINIT;
    objectsByUUID_ = [[NSMutableDictionary alloc] init];
    insertedObjects_ = [[NSMutableSet alloc] init];
    modifiedObjects_ = [[NSMutableSet alloc] init];
    _updatedPropertiesByObject = [[NSMapTable alloc] init];
    branch_ = aBranch;
    if (aRepo == nil)
    {
        aRepo = [[[branch_ persistentRoot] editingContext] modelRepository];
    }
    
    ASSIGN(modelRepository_, aRepo);
    return self;
}

- (id) initWithBranch: (COBranch *)aBranch
{
    return [self initWithBranch: aBranch modelRepository: nil];
}

- (id) initWithModelRepository: (ETModelDescriptionRepository *)aRepo
{
    return [self initWithBranch: nil modelRepository: aRepo];
}

- (id) init
{
    return [self initWithModelRepository: [ETModelDescriptionRepository mainRepository]];
}

+ (COObjectGraphContext *) objectGraphContext
{
    return [[[self alloc] init] autorelease];
}

+ (COObjectGraphContext *) objectGraphContextWithModelRepository: (ETModelDescriptionRepository *)aRegistry
{
    return [[[self alloc] initWithModelRepository: aRegistry] autorelease];
}

- (void) dealloc
{
    [objectsByUUID_ release];
    [rootObjectUUID_ release];
    [insertedObjects_ release];
    [modifiedObjects_ release];
    [modelRepository_ release];
    [_updatedPropertiesByObject release];
    [super dealloc];
}

#pragma mark Schema

- (ETModelDescriptionRepository *) modelRepository;
{
    return modelRepository_;
}

- (COBranch *) branch
{
    return branch_;
}

- (void)setBranch: (COBranch *)aBranch
{
	branch_ = aBranch;
}

- (COPersistentRoot *) persistentRoot
{
    return [branch_ persistentRoot];
}

- (COEditingContext *) editingContext
{
    return [[branch_ persistentRoot] parentContext];
}

#pragma mark begin COItemGraph protocol

- (ETUUID *) rootItemUUID
{
    return rootObjectUUID_;
}

/**
 * Returns immutable item
 */
- (COItem *) itemForUUID: (ETUUID *)aUUID
{
    COObject *object = [objectsByUUID_ objectForKey: aUUID];
	return [object storeItem];
}

- (NSArray *) itemUUIDs
{
    return [objectsByUUID_ allKeys];
}

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
    
	ETEntityDescription *desc = [modelRepository_ descriptionForName: name];
    
    if (desc == nil)
    {
        desc = [modelRepository_ descriptionForName: [self defaultEntityName]];
    }
    
    return desc;
}

- (id) objectReferenceWithUUID: (ETUUID *)aUUID
{
	COObject *loadedObject = [objectsByUUID_ objectForKey: aUUID];

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

- (id) objectWithUUID: (ETUUID *)aUUID
    entityDescription: (ETEntityDescription *)anEntityDescription
{
	Class objClass = [modelRepository_ classForEntityDescription: anEntityDescription];
	/* For a reloaded object, we must no call -initWithUUID:entityDescription:context:
	   to prevent the normal initialization process to occur (the COObject
	   subclass designed initializer being called). */
	COObject *obj = [[objClass alloc] commonInitWithUUID: aUUID
                                       entityDescription: anEntityDescription
	                                  objectGraphContext: self];
	
	[objectsByUUID_ setObject: obj forKey: aUUID];
	[obj release];
	
	return obj;
}

- (COObject *)objectWithStoreItem: (COItem *)anItem
{
	NILARG_EXCEPTION_TEST(anItem);
    
	COObject *obj = [self objectWithUUID: [anItem UUID]
	                   entityDescription: [self descriptionForItem: anItem]];

    [obj setStoreItem: anItem];
	[obj addCachedOutgoingRelationships];
	
	return obj;
}

/**
 * Insert or update an item.
 */
- (void) addItem: (COItem *)item markAsInserted: (BOOL)markInserted
{
    NSParameterAssert(item != nil);
    
    ETUUID *uuid = [item UUID];
    COObject *currentObject = [objectsByUUID_ objectForKey: uuid];
    
    if (currentObject == nil)
    {
        currentObject = [self objectWithStoreItem: item];
        if (markInserted)
        {
            [insertedObjects_ addObject: currentObject];
        }
    }
    else
    {
        [currentObject setStoreItem: item];
        [currentObject addCachedOutgoingRelationships];
        [modifiedObjects_ addObject: currentObject];
    }
}

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
    return [self insertObjectWithEntityName: aFullName UUID: [ETUUID UUID]];
}

- (id)insertObjectWithEntityName: (NSString *)aFullName
                            UUID: (ETUUID *)aUUID
{
    ETEntityDescription *desc = [modelRepository_ descriptionForName: aFullName];
    if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	Class objClass = [modelRepository_ classForEntityDescription: desc];
    
    /* Nil root object means the new object will be a root */
	COObject *obj = [[objClass alloc] initWithUUID: aUUID
                                 entityDescription: desc
                                objectGraphContext: self];
	[obj release];
    
    [obj addCachedOutgoingRelationships];
    
	return obj;
}

- (void)registerObject: (COObject *)object
{
	NILARG_EXCEPTION_TEST(object);
	INVALIDARG_EXCEPTION_TEST(object, [object isKindOfClass: [COObject class]]);

    ETUUID *uuid = [object UUID];
    
	INVALIDARG_EXCEPTION_TEST(object, [objectsByUUID_ objectForKey: uuid] == nil);
    
    [objectsByUUID_ setObject: object forKey: uuid];
	[insertedObjects_ addObject: object];
}

- (void) insertOrUpdateItems: (NSArray *)items
{
    if ([items count] == 0)
        return;
    
    // Wrap the items array in a COItemGraph, so they can be located by
    // -objectReferenceWithUUID:. The rootItemUUID is ignored.
    ASSIGN(_loadingItemGraph, [[[COItemGraph alloc] initWithItems: items
                                                     rootItemUUID: [[items objectAtIndex: 0] UUID]] autorelease]);
    
    for (COItem *item in items)
    {
        [self addItem: item markAsInserted: NO];
    }
	
	DESTROY(_loadingItemGraph);
}


#pragma mark end COItemGraph protocol

/**
 * Replaces the editing context.
 *
 * There are 3 kinds of change:
 *  - New objects are inserted
 *  - Removed objects are removed
 *  - Changed objects are updated. (sub-case: identical objects)
 */
- (void) setItemGraph: (id <COItemGraph>)aTree
{
    [self clearChangeTracking];

    // 1. Do updates.

    ASSIGN(rootObjectUUID_, [aTree rootItemUUID]);
    
	// TODO: To prevent caching the item graph during the loading, a better
	// approach could be to allocate all the objects before loading them.
	// We could also change -[COObjectGraphContext itemForUUID:] to search aTree
	// during the loading rather than the loaded objects (but that's roughly the
	// same than we do currently).
	ASSIGN(_loadingItemGraph, aTree);

    for (ETUUID *uuid in [aTree itemUUIDs])
    {
        [self addItem: [aTree itemForUUID: uuid] markAsInserted: NO];
    }
	
	DESTROY(_loadingItemGraph);
    
    // 3. Do GC
    
    [self gc_];
    
    // 4. Clear change tracking again.
    
    [self clearChangeTracking];
}

- (COObject *) rootObject
{
	/* To support -rootObject access during the root object instantiation */
	if ([self rootItemUUID] == nil)
		return nil;

    return [self objectWithUUID: [self rootItemUUID]];
}

- (void) setRootObject: (COObject *)anObject
{
    NSParameterAssert([anObject objectGraphContext] == self);
    ASSIGN(rootObjectUUID_, [anObject UUID]);
}

#pragma mark change tracking

/**
 * Returns the set of objects inserted since change tracking was cleared
 */
- (NSSet *) insertedObjects
{
    return insertedObjects_;
}
/**
 * Returns the set of objects modified since change tracking was cleared
 */
- (NSSet *) updatedObjects
{
    return modifiedObjects_;
}
- (NSSet *) changedObjects
{
    return [insertedObjects_ setByAddingObjectsFromSet: modifiedObjects_];
}
- (BOOL) isUpdatedObject: (COObject *)anObject
{
    return [modifiedObjects_ containsObject: anObject];
}
- (BOOL)hasChanges
{
	return [[self changedObjects] count] > 0;
}
- (NSArray *) allObjects
{
    return [objectsByUUID_ allValues];
}

- (void) clearChangeTracking
{
    [insertedObjects_ removeAllObjects];
    [modifiedObjects_ removeAllObjects];
    [_updatedPropertiesByObject removeAllObjects];
}

- (void) clearChangeTrackingForObject: (COObject *)anObject
{
    [insertedObjects_ removeObject: anObject];
    [modifiedObjects_ removeObject: anObject];
    [_updatedPropertiesByObject removeObjectForKey: anObject];
}

- (NSMapTable *) updatedPropertiesByObject
{
    return _updatedPropertiesByObject;
}

#pragma mark access

- (COObject *) objectWithUUID: (ETUUID *)aUUID
{
	// NOTE: We serialize UUIDs into strings in various places, this check
	// helps to intercept string objects that ought to be ETUUID objects.
	NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
    COObject *obj = [objectsByUUID_ objectForKey: aUUID];
	ETAssert([obj isKindOfClass: [COObject class]]);
	return obj;
}

#pragma mark garbage collection

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
- (void) removeSingleObject_: (ETUUID *)uuid
{
    COObject *anObject = [objectsByUUID_ objectForKey: uuid];
    
    // Update relationship cache
    
    [anObject removeCachedOutgoingRelationships];
    
    // Update change tracking
    
    [insertedObjects_ removeObject: anObject];
    [modifiedObjects_ removeObject: anObject];
    
    // Mark the object as a "zombie"
    
    [anObject markAsRemovedFromContext];
    
    // Release it from the objects dictionary (may release it)
    
    [objectsByUUID_ removeObjectForKey: uuid];
    anObject = nil;
}

- (void) gcDfs_: (COObject *)anObject uuids: (NSMutableSet *)set
{
    ETUUID *uuid = [anObject UUID];
    if ([set containsObject: uuid])
    {
        return;
    }
    [set addObject: uuid];
    
    // Call recursively on all composite and referenced objects
    for (COObject *obj in [anObject embeddedOrReferencedObjects])
    {
        [self gcDfs_: obj uuids: set];
    }
}

- (void) gc_
{
    if ([self rootObject] == nil)
    {
        return;
    }
    
    NSArray *allKeys = [objectsByUUID_ allKeys];
    
    NSMutableSet *live = [NSMutableSet setWithCapacity: [allKeys count]];
    [self gcDfs_: [self rootObject] uuids: live];
    
    NSMutableSet *dead = [NSMutableSet setWithArray: allKeys];
    [dead minusSet: live];
    
    for (ETUUID *deadUUID in dead)
    {
        [self removeSingleObject_: deadUUID];
    }
}

#pragma mark equality, hash

- (BOOL) isEqual:(id)object
{
    if (object == self)
    {
        return YES;
    }
	if (![object isKindOfClass: [self class]])
	{
		return NO;
	}
    
    COObjectGraphContext *otherContext = (COObjectGraphContext *)object;
    
    if (!((rootObjectUUID_ == nil && otherContext->rootObjectUUID_ == nil)
          || [rootObjectUUID_ isEqual: otherContext->rootObjectUUID_]))
    {
        return NO;
    }
    
    if (![[NSSet setWithArray: [self itemUUIDs]]
          isEqual: [NSSet setWithArray: [otherContext itemUUIDs]]])
    {
        return NO;
    }
    
    for (ETUUID *aUUID in [self itemUUIDs])
    {
        COItem *selfItem = [[self objectWithUUID: aUUID] storeItem];
        COItem *otherItem = [[otherContext objectWithUUID: aUUID] storeItem];
        if (![selfItem isEqual: otherItem])
        {
            return NO;
        }
    }
    return YES;
}

- (NSUInteger) hash
{
	return [rootObjectUUID_ hash] ^ 13803254444065375360ULL;
}

#pragma mark COObject private methods

- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty
{
	if (nil == [_updatedPropertiesByObject objectForKey: obj])
	{
		[_updatedPropertiesByObject setObject: [NSMutableArray array] forKey: obj];
	}
	if (aProperty != nil)
	{
		assert([aProperty isKindOfClass: [NSString class]]);
		[[_updatedPropertiesByObject objectForKey: obj] addObject: aProperty];
	}
    
    // If it's already marked as inserted, don't mark it as modified
    if (![insertedObjects_ containsObject: obj])
    {
        [modifiedObjects_ addObject: obj];
    }
}

@end
