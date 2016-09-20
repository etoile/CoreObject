/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COCrossPersistentRootDeadRelationshipCache.h"
#import "COEditingContext+Private.h"
#import "COItemGraph.h"
#import "COObjectGraphContext+GarbageCollection.h"
#import "CORelationshipCache.h"
#import "COObject+Private.h"
#import "COObject+RelationshipCache.h"
#import "COMetamodel.h"
#import "COSerialization.h"
#import "COSchemaMigrationDriver.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COBranch+Private.h"
#import "COItem.h"
#import "CODictionary.h"
#import "COPath.h"

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
@synthesize migrationDriverClass = _migrationDriverClass;

#pragma mark Creation

- (instancetype)initWithBranch: (COBranch *)aBranch
     modelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
	       migrationDriverClass: (Class)aDriverClass
{
	INVALIDARG_EXCEPTION_TEST(aDriverClass, aDriverClass == Nil || [aDriverClass isSubclassOfClass: [COSchemaMigrationDriver class]]);

    SUPERINIT;
    _loadedObjects = [[NSMutableDictionary alloc] init];
	_objectsByAdditionalItemUUIDs = [[NSMutableDictionary alloc] init];
    _insertedObjectUUIDs = [[NSMutableSet alloc] init];
    _updatedObjectUUIDs = [[NSMutableSet alloc] init];
    _updatedPropertiesByUUID = [[NSMutableDictionary alloc] init];
    _branch = aBranch;
	_persistentRoot = aBranch.persistentRoot;
	_futureBranchUUID = (aBranch == nil ? [ETUUID UUID] : nil);
    if (aRepo == nil)
    {
        aRepo = _persistentRoot.editingContext.modelDescriptionRepository;
    }
	else
	{
		CORegisterCoreObjectMetamodel(aRepo);
	}
    _modelDescriptionRepository = aRepo;
	if (aDriverClass == Nil)
	{
		_migrationDriverClass = _persistentRoot.editingContext.migrationDriverClass;
	}
	else
	{
		_migrationDriverClass = aDriverClass;
	}
	
	ETAssert(_modelDescriptionRepository != nil);
	ETAssert(_migrationDriverClass != Nil);

    return self;
}

- (instancetype)initWithBranch: (COBranch *)aBranch
{
    return [self initWithBranch: aBranch modelDescriptionRepository: nil migrationDriverClass: Nil];
}

- (instancetype)initWithModelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
                    migrationDriverClass: (Class)aDriverClass
{
	NILARG_EXCEPTION_TEST(aRepo);
	NILARG_EXCEPTION_TEST(aDriverClass);
    return [self initWithBranch: nil modelDescriptionRepository: aRepo migrationDriverClass: aDriverClass];
}

- (instancetype)init
{
    return [self initWithModelDescriptionRepository: [ETModelDescriptionRepository mainRepository]
	                           migrationDriverClass: [COSchemaMigrationDriver class]];
}

+ (COObjectGraphContext *)objectGraphContext
{
    return [[self alloc] init];
}

+ (COObjectGraphContext *)objectGraphContextWithModelDescriptionRepository: (ETModelDescriptionRepository *)aRepo
{
    return [[self alloc] initWithModelDescriptionRepository: aRepo
	                                   migrationDriverClass: [COSchemaMigrationDriver class]];
}

- (void)dealloc
{
	[self discardAllObjects];
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"<%@: %p - %@ - rootObject: %@>",
		NSStringFromClass([self class]), self, [self branchUUID], self.rootItemUUID];
}

- (NSString *)detailedDescription
{
	NSMutableString *result = [NSMutableString string];
    
	[result appendFormat: @"[COObjectGraphContext root: %@\n", self.rootItemUUID];
	for (ETUUID *uuid in self.itemUUIDs)
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
		return _persistentRoot.currentBranch;
	}
	return _branch;
}

- (void)setBranch: (COBranch *)aBranch
{
	_branch = aBranch;
	_persistentRoot = aBranch.persistentRoot;
}

- (ETUUID *)branchUUID
{
	return (self.branch != nil ? self.branch.UUID : _futureBranchUUID);
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
    return _persistentRoot.parentContext;
}

- (BOOL) isTrackingSpecificBranch
{
	return _persistentRoot != nil && self != _persistentRoot.objectGraphContext;
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
	
	_loadedObjects[aUUID] = obj;
	
	return obj;
}

- (id)objectReferenceWithUUID: (ETUUID *)aUUID
{
    ETAssert(_loadingItemGraph != nil);
	
	COObject *loadedObject = _loadedObjects[aUUID];

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
    
	COObject *obj = [self objectWithUUID: anItem.UUID
	                   entityDescription: [self descriptionForItem: anItem]];

    obj.storeItem = anItem;

	return obj;
}

- (id <COItemGraph>)loadingItemGraph
{
	return _loadingItemGraph;
}

/**
 * Sends -willLoadObjectGraph to the existing objects to be reloaded by 
 * deserializing the given items.
 *
 * Objects loaded for the first time don't receive -willLoadObjectGraph.
 *
 * The item UUIDs must not included UUIDs corresponding to additional items.
 */
- (void)beginLoadingObjectsWithUUIDs: (NSSet *)itemUUIDs
{
	for (ETUUID *UUID in itemUUIDs)
	{
		COObject *object = [self loadedObjectForUUID: UUID];

		if (object == nil)
			continue;

		[object willLoadObjectGraph];
	}
}

/**
 * Sends -didLoadObjectGraph to the objects just reloaded by deserializing the
 * given items.
 *
 * The root object (if deserialized), is the last object to receive 
 * -didLoadObjectGraph.
 *
 * The item UUIDs must not included UUIDs corresponding to additional items.
 */
- (void)finishLoadingObjectsWithUUIDs: (NSSet *)itemUUIDs
{
	for (ETUUID *UUID in itemUUIDs)
	{
		// NOTE: Based on the assumption, the root object UUID remains the same
		BOOL isRootObject = [self.rootItemUUID isEqual: UUID];

		if (isRootObject)
			continue;
		
		COObject *object = [self loadedObjectForUUID: UUID];
		ETAssert(object != nil);

		[object didLoadObjectGraph];
	}

	BOOL wasRootObjectDeserialized = [itemUUIDs containsObject: self.rootItemUUID];

	if (wasRootObjectDeserialized)
	{
		[self.rootObject didLoadObjectGraph];
	}
}

#pragma mark -
#pragma mark Loading Status

- (BOOL)isLoading
{
	return _loadingItemGraph != nil;
}

#pragma mark -
#pragma mark Item Graph Protocol

- (ETUUID *)rootItemUUID
{
    return _rootObjectUUID;
}

- (COItem *)itemForUUID: (ETUUID *)aUUID
{
	ETAssert([aUUID isKindOfClass: [ETUUID class]]);
	
    COObject *object = _loadedObjects[aUUID];
	
	if (object != nil)
		return object.storeItem;

	return [_objectsByAdditionalItemUUIDs[aUUID] additionalStoreItemForUUID: aUUID];
}

- (NSArray *)itemUUIDs
{
    NSArray *additionalItemUUIDs = _objectsByAdditionalItemUUIDs.allKeys;

	return [_loadedObjects.allKeys arrayByAddingObjectsFromArray: additionalItemUUIDs];
}

- (NSArray *)items
{
	NSMutableArray *items = [NSMutableArray new];

	for (ETUUID *itemUUID in self.itemUUIDs)
	{
		[items addObject: [self itemForUUID: itemUUID]];
	}
	return items;
}

/**
 * Returns the owner item to load or reload to get the additional item looked up
 * in the loading item graph, and deserialized into a property. 
 *
 * For example, see -dictionaryFromStoreItem:propertyDescription: call in
 * COSerialization.
 * 
 * Additional items are deserialized by their owner object deserialization, to
 * ensure -awakeFromDeserialization is called on the owner object.
 */
- (COItem *)ownerItemForAdditionalItem: (COItem *)item
{
	NSParameterAssert(item != nil);
	NSParameterAssert(item.isAdditionalItem);
	ETAssert(_loadingItemGraph != nil);

	/* When the owner is nil, this means the additional item is loaded for the 
	   first time, and the owner item is present in the loading item graph, but
	   its UUID cannot be known until it is deserialized. */
	COObject *owner = _objectsByAdditionalItemUUIDs[item.UUID];
	COItem *ownerItem = [_loadingItemGraph itemForUUID: owner.UUID];

	if (ownerItem == nil && owner != nil)
	{
		ownerItem = [self itemForUUID: owner.UUID];
	}
	return ownerItem;
}

- (void)updateMappingFromAdditionalItemsToObject: (COObject *)currentObject
{
	for (ETUUID *itemUUID in [currentObject.additionalStoreItemUUIDs objectEnumerator])
	{
		_objectsByAdditionalItemUUIDs[itemUUID] = currentObject;
	}
	ETAssert([[_objectsByAdditionalItemUUIDs allKeys] containsCollection: [[currentObject additionalStoreItemUUIDs] allValues]]);
}

/**
 * Caller must handle marking the item as inserted/updated, if desired.
 */
- (void)addItem: (COItem *)item
{
    NSParameterAssert(item != nil);
	NSParameterAssert(!item.isAdditionalItem);
	ETAssert(_loadingItemGraph != nil);

    ETUUID *uuid = item.UUID;
    COObject *currentObject = _loadedObjects[uuid];
    
    if (currentObject == nil)
    {
        currentObject = [self objectWithStoreItem: item];
    }
    else
    {
        currentObject.storeItem = item;
    }

	[self updateMappingFromAdditionalItemsToObject: currentObject];
}

- (NSSet *)mainItemsFromItemGraph: (id <COItemGraph>)itemGraph
                    loadableUUIDs: (NSSet *)itemUUIDs
{
	NSMutableSet *items = [NSMutableSet setWithCapacity: itemUUIDs.count];
	
	for (ETUUID *UUID in itemUUIDs)
	{
		COItem *item = [itemGraph itemForUUID: UUID];
		
		if (item.isAdditionalItem)
		{
			item = [self ownerItemForAdditionalItem: item];
		}
		if (item == nil)
			continue;

		[items addObject: item];
	}

	return items;
}

- (void)addItemsFromItemGraph: (id <COItemGraph>)itemGraph
                loadableUUIDs: (NSSet *)itemUUIDs
{
	NSParameterAssert(itemGraph != nil);
	NSParameterAssert(itemUUIDs != nil);

	// NOTE: To prevent caching the item graph during the loading, a better
	// approach could be to allocate all the objects before loading them.
	// We could also change -[COObjectGraphContext itemForUUID:] to search
	// itemGraph during the loading rather than the loaded objects (but that's
	// roughly the same than we do currently).
	COSchemaMigrationDriver *migrationDriver = [[self.migrationDriverClass alloc]
		initWithModelDescriptionRepository: self.modelDescriptionRepository];
	NSArray *migratedItems = [migrationDriver migrateItems: itemGraph.items];
	_loadingItemGraph = [[COItemGraph alloc] initWithItems: migratedItems
	                                          rootItemUUID: itemGraph.rootItemUUID];
	// TODO: Decide how we update the change tracking in regard to additional items.

	// Update change tracking
	for (ETUUID *UUID in itemUUIDs)
	{
		if (_loadedObjects[UUID] != nil)
		{
			// TODO: Check it the item is actually different?
			[_updatedObjectUUIDs addObject: UUID];
		}
		else
		{
			[_insertedObjectUUIDs addObject: UUID];
		}
	}
	
	NSSet *mainItems = [self mainItemsFromItemGraph: _loadingItemGraph
									  loadableUUIDs: itemUUIDs];
	NSSet *mainItemUUIDs = (id)[[mainItems mappedCollection] UUID];

	[self beginLoadingObjectsWithUUIDs: mainItemUUIDs];
	for (COItem *item in mainItems)
    {
		[self addItem: item];
    }
	[self finishLoadingObjectsWithUUIDs: mainItemUUIDs];
	
	_loadingItemGraph = nil;
}

- (void)insertOrUpdateItems: (NSArray *)items
{
	NILARG_EXCEPTION_TEST(items);

    if (items.count == 0)
        return;

	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextBeginBatchChangeNotification
														object: self];

	// Wrap the items array in a COItemGraph, so they can be located by
    // -objectReferenceWithUUID:. The rootItemUUID is ignored.
    COItemGraph *itemGraph =
		[[COItemGraph alloc] initWithItems: items
                              rootItemUUID: [[items firstObject] UUID]];
	
	[self addItemsFromItemGraph: itemGraph
	              loadableUUIDs: [NSSet setWithArray: itemGraph.itemUUIDs]];
	
	// NOTE: -acceptAllChanges *not* called
	
	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextEndBatchChangeNotification
														object: self];
}

- (void)setItemGraph: (id <COItemGraph>)aTree
{
	[[NSNotificationCenter defaultCenter] postNotificationName: COObjectGraphContextBeginBatchChangeNotification
														object: self];
	
	NILARG_EXCEPTION_TEST(aTree);
	// i.e., the root object can be set once and never changed.
	INVALIDARG_EXCEPTION_TEST(aTree, _rootObjectUUID == nil || [_rootObjectUUID isEqual: aTree.rootItemUUID]);
    _rootObjectUUID =  aTree.rootItemUUID;
    
	NSSet *aTreeReachableUUIDs = COItemGraphReachableUUIDs(aTree);
	if (aTreeReachableUUIDs.count == 0)
	{
		// Special case. Both the givem graph, and the receiver have no root UUID.
		// In that case, just take all of the objects from the aTree
		
		aTreeReachableUUIDs = [NSSet setWithArray: aTree.itemUUIDs];
	}

	[self addItemsFromItemGraph: aTree
				  loadableUUIDs: aTreeReachableUUIDs];
    
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
	if (self.rootItemUUID == nil)
		return nil;

    return [self loadedObjectForUUID: self.rootItemUUID];
}

- (void)setRootObject: (COObject *)anObject
{
    NSParameterAssert([anObject objectGraphContext] == self);
	// i.e., the root object can be set once and never changed.
	NSParameterAssert(_rootObjectUUID == nil || [_rootObjectUUID isEqual: [anObject UUID]]);
	
    _rootObjectUUID =  anObject.UUID;
}

#pragma mark -
#pragma mark Object Insertion

- (void)registerObject: (COObject *)object isNew: (BOOL)inserted
{
	NILARG_EXCEPTION_TEST(object);
	INVALIDARG_EXCEPTION_TEST(object, [object isKindOfClass: [COObject class]]);

    ETUUID *uuid = object.UUID;
    
	INVALIDARG_EXCEPTION_TEST(object, _loadedObjects[uuid] == nil);
    
    _loadedObjects[uuid] = object;

	if (inserted)
	{
		[_insertedObjectUUIDs addObject: uuid];
		
		for (ETUUID *itemUUID in [object.additionalStoreItemUUIDs objectEnumerator])
		{
			_objectsByAdditionalItemUUIDs[itemUUID] = object;
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
	if (self.ignoresChangeTrackingNotifications)
		return;
	
	ETAssert([aProperty isKindOfClass: [NSString class]]);

	ETUUID *uuid = obj.UUID;
	NSMutableArray *updatedProperties = _updatedPropertiesByUUID[uuid];

	if (nil == updatedProperties)
	{
		updatedProperties = [NSMutableArray array];
		_updatedPropertiesByUUID[uuid] = updatedProperties;
	}
	[updatedProperties addObject: aProperty];
    
    // If it's already marked as inserted, don't mark it as updated
    if (![_insertedObjectUUIDs containsObject: uuid])
    {
        [_updatedObjectUUIDs addObject: uuid];
    }
}
   
- (BOOL)hasChanges
{
	return _updatedObjectUUIDs.count > 0
		|| _insertedObjectUUIDs.count > 0;
}
   
- (void)discardAllChanges
{
	if (self.branch == nil)
	{
		[self discardAllObjects];
		[self acceptAllChanges];
		ETAssert([[self loadedObjects] isEmpty]);
	}
	else
	{
		[self.branch reloadAtRevision: self.branch.currentRevision];
	}
}

- (void)discardAllObjects
{
	[self discardObjectsWithUUIDs:  [NSSet setWithArray: _loadedObjects.allKeys]];
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
        [obj willDiscard];
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
	ETUUID *uuid = anObject.UUID;
	
    // Mark the object as a "zombie"
    
    [anObject markAsRemovedFromContext];
	
	// Update change tracking
    
    [_insertedObjectUUIDs removeObject: uuid];
    [_updatedObjectUUIDs removeObject: uuid];

	// Remove it from the additional item to object lookup table

	[_objectsByAdditionalItemUUIDs removeObjectsForKeys: anObject.additionalStoreItemUUIDs.allValues];
    
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
	return [self loadedObjectsForUUIDs: _insertedObjectUUIDs.allObjects];
}

- (NSArray *)updatedObjects
{
	return [self loadedObjectsForUUIDs: _updatedObjectUUIDs.allObjects];
}

- (NSArray *)changedObjects
{
	return [self loadedObjectsForUUIDs: self.changedObjectUUIDs.allObjects];
}

- (NSDictionary *)updatedPropertiesByUUID
{
	return _updatedPropertiesByUUID;
}

#pragma mark -
#pragma mark Accessing Loaded Objects

- (NSArray *)loadedObjects
{
    return _loadedObjects.allValues;
}

- (COObject *)loadedObjectForUUID: (ETUUID *)aUUID
{
	// NOTE: We serialize UUIDs into strings in various places, this check
	// helps to intercept string objects that ought to be ETUUID objects.
	NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
    COObject *obj = _loadedObjects[aUUID];
	ETAssert(obj == nil || [obj isKindOfClass: [COObject class]]);
	return obj;
}

- (NSArray *)loadedObjectsForUUIDs: (NSArray *)UUIDs
{
	NSMutableArray *objects = [NSMutableArray arrayWithCapacity: UUIDs.count];

	for (ETUUID *UUID in UUIDs)
	{
        COObject *obj = [self loadedObjectForUUID: UUID];

        if (obj == nil)
            continue;

		[objects addObject: obj];
	}
	return objects;
}


#pragma mark -
#pragma mark Garbage Collection

- (void)removeUnreachableObjects
{
    if (self.rootObject == nil)
    {
        return;
    }
    
    NSMutableSet *deadUUIDs = [NSMutableSet setWithArray: _loadedObjects.allKeys];
	NSSet *liveUUIDs = self.allReachableObjectUUIDs;
    [deadUUIDs minusSet: liveUUIDs];
	
	[self discardObjectsWithUUIDs: deadUUIDs];
}

/**
 * The undeleted object is an outer root object that may be referenced by
 * outgoing relationships of the receiver inner objects.
 *
 * The referring objects are the inner objects that hold a reference to it.
 *
 * For -updateCrossPersistentRootReferencesToPersistentRoot:branch:isFault:,
 * this method is a bottleneck. To make it even faster, we could access ivars
 * directly and preallocate some COPath objects.
 */
- (NSSet *)referringObjectsWithDeadReferencesToObject: (COObject *)undeletedObject
{
	COObjectGraphContext *undeletedObjectGraphContext = undeletedObject.objectGraphContext;

	ETAssert(undeletedObjectGraphContext != self);
	ETDebugAssert(undeletedObject == undeletedObjectGraphContext.rootObject);

	if (_persistentRoot == nil)
		return [NSSet set];

	COCrossPersistentRootDeadRelationshipCache *deadRelationshipCache =
		_persistentRoot.parentContext.deadRelationshipCache;
	COPath *pathToUndeletedObject = nil;
	
	if (undeletedObjectGraphContext.trackingSpecificBranch)
	{
		pathToUndeletedObject = [COPath pathWithPersistentRoot: undeletedObjectGraphContext.persistentRoot.UUID
		                                                branch: undeletedObjectGraphContext.branch.UUID];
	}
	else
	{
		pathToUndeletedObject = [COPath pathWithPersistentRoot: undeletedObjectGraphContext.persistentRoot.UUID];
	}

	return [deadRelationshipCache referringObjectsForPath: pathToUndeletedObject].setRepresentation;
}

- (BOOL) ignoresChangeTrackingNotifications
{
	return _ignoresChangeTrackingNotifications > 0;
}

- (void) setIgnoresChangeTrackingNotifications: (BOOL)flag
{
	if (flag)
	{
		_ignoresChangeTrackingNotifications++;
	}
	else
	{
		_ignoresChangeTrackingNotifications--;
		ETAssert(_ignoresChangeTrackingNotifications >= 0);
	}
}

/**
 * This method is called on every object graph containing one or more referring 
 * objects (the relationship sources) whose properties needs to be updated to 
 * point to the proposed replacement (the new relationship target).
 *
 * When deleting a persistent root, other persistent root object graphs will
 * receive this message with a nil object as second argument, so referring
 * objects will contain live references (matching the the first argument) to
 * be replaced by COPath markers.
 *
 * When undeleting a persistent root, other persistent root object graphs will 
 * receive this message with a nil object as first argument, so referring 
 * objects will contain hidden dead references (COPath markers) to be replaced 
 * by the second argument.
 *
 * For this method, referring objects are inner objects of the receiver.
 */
- (void)replaceObject: (COObject *)anObject withObject: (COObject *)aReplacement
{
	NSSet *referringObjects = nil;
	BOOL isUndeletion = (anObject == nil);
	
	if (isUndeletion)
	{
		referringObjects = [self referringObjectsWithDeadReferencesToObject: aReplacement];
	}
	else
	{
		referringObjects = anObject.incomingRelationshipCache.referringObjects;
	}

	self.ignoresChangeTrackingNotifications = YES;
	for (COObject *referrer in referringObjects)
	{
        if (referrer.objectGraphContext != self)
            continue;
        
		[referrer replaceReferencesToObjectIdenticalTo: anObject
											withObject: aReplacement];
	}
	self.ignoresChangeTrackingNotifications = NO;
}

- (COItemGraph *)modifiedItemsSnapshot
{
    NSSet *objectUUIDs = self.changedObjectUUIDs;
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    for (ETUUID *uuid in objectUUIDs)
    {
        COItem *item = [self itemForUUID: uuid];
        dict[uuid] = item;
    }
    
    COItemGraph *modifiedItems = [[COItemGraph alloc] initWithItemForUUID: dict
															 rootItemUUID: self.rootItemUUID];
	return modifiedItems;
}

#define GC_INTERVAL 1000

- (BOOL) incrementCommitCounterAndCheckIfGCNeeded
{
	_numberOfCommitsSinceLastGC++;
	
	if (_numberOfCommitsSinceLastGC == GC_INTERVAL)
	{
		_numberOfCommitsSinceLastGC = 0;
		return YES;
	}

#if defined(DEBUG)
	return YES;
#else
	return NO;
#endif
}

- (void) doPreCommitChecks
{
	// Possibly garbage-collect the context we are going to commit.
	//
	// This only happens every 1000 commits in release builds, or every commit in debug builds
	// Skip the garbage collection if there are no changes to commit.
	//
	// Rationale:
	//
	// In debug builds, we want to make sure application developers don't
	// rely on garbage objects remaining uncollected, since it could lead to
	// incorrect application code that works most of the time.
	//
	// However, in release builds, it's worth only doing the garbage collection
	// occassionally, since the garbage collection requires looking at every
	// object and not just the modified ones being committed.
	//
	// The only caveat is, if you modify objects and detached them from the graph
	// in the same transaction, they still get committed. This isn't a big deal
	// becuase this should be rare (only a strange app would do this), and the
	// detached objects will be ignored at reloading time.
	if (self.hasChanges)
	{
		if ([self incrementCommitCounterAndCheckIfGCNeeded])
		{
			[self removeUnreachableObjects];
		}
	}
	
	// Check for composite cycles - see [TestOrderedCompositeRelationship testCompositeCycleWithThreeObjects]
	[self checkForCyclesInCompositeRelationshipsInChangedObjects];
}

@end
