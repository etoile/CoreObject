/*
	Copyright (C) 2012 Quentin Mathe
 
	Author:  Quentin Mathe <quentin.mathe@gmail.com>, 
	         Eric Wasylishen <ewasylishen@gmail.com>
	Date:  November 2012
	License:  Modified BSD  (see COPYING)
 */

#import "COPersistentRoot.h"
#import "COCommitTrack.h"
#import "COEditingContext.h"
#import "COError.h"
#import "COItem.h"
#import "COObject.h"
#import "COPersistentRoot+RelationshipCache.h"
#import "CORelationshipCache.h"
#import "CORevision.h"
#import "COSerialization.h"
#import "COSQLiteStore.h"

@implementation COPersistentRoot

@synthesize parentContext = _parentContext,
	commitTrack = _commitTrack, rootObject = _rootObject;

- (ETUUID *)persistentRootUUID
{
    return [_info UUID];
}

- (id)initWithInfo: (COPersistentRootInfo *)info
     parentContext: (COEditingContext *)aCtxt
{
	NILARG_EXCEPTION_TEST(aCtxt);

	SUPERINIT;
    
    if (info == nil)
    {
        COBranchInfo *branchInfo = [[COBranchInfo alloc] init];
        branchInfo.UUID = [ETUUID UUID];
        
        _info = [[COPersistentRootInfo alloc] init];
        _info.UUID = [ETUUID UUID];
        _info.currentBranchUUID = branchInfo.UUID;
        _info.branchForUUID = D(branchInfo, branchInfo.UUID);
    }
    else
    {
        ASSIGN(_info, info);
    }

	_parentContext = aCtxt;
	if ([_parentContext store] != nil)
	{
		_commitTrack = [[COCommitTrack alloc] initWithUUID: _info.currentBranchUUID persistentRoot: self];
	}
	
    CORevisionID *revId = [[_info currentBranchInfo] currentRevisionID];
    if (revId != nil)
    {
        // FIXME: Ugly to have a store access here. Perhaps CORevision should do it lazily?
        CORevisionInfo *revInfo = [[_parentContext store] revisionInfoForRevisionID: revId];
        
        _revision = [[CORevision alloc] initWithStore: [_parentContext store]
                                         revisionInfo: revInfo];
    }
    
	_loadedObjects = [NSMutableDictionary new];
	_insertedObjects = [NSMutableSet new];
	_deletedObjects = [NSMutableSet new];
	ASSIGN(_updatedPropertiesByObject, [NSMapTable mapTableWithStrongToStrongObjects]);
    _relationshipCache = [[CORelationshipCache alloc] init];
    
    // Load all of the objects
    if (_revision != nil)
    {
        [self reloadAtRevision: _revision];
    }
    
	return self;
}

- (void)dealloc
{
	DESTROY(_info);
	DESTROY(_commitTrack);
	DESTROY(_rootObject);
	DESTROY(_revision);
	DESTROY(_loadedObjects);
	DESTROY(_insertedObjects);
	DESTROY(_deletedObjects);
	DESTROY(_updatedPropertiesByObject);
    DESTROY(_relationshipCache);
	[super dealloc];
}

- (NSString *)description
{
	// TODO: Improve the indenting
	NSString *desc = [D([self insertedObjects], @"Inserted Objects",
	                    [self deletedObjects], @"Deleted Objects",
	                    _updatedPropertiesByObject, @"Updated Objects") description];
	/* For Mac OS X, see http://www.cocoabuilder.com/archive/cocoa/197297-who-broke-nslog-on-leopard.html */
	return [desc stringByReplacingOccurrencesOfString: @"\\n" withString: @"\n"];
}

- (BOOL)isPersistentRoot
{
	return YES;
}

- (BOOL)isEditingContext
{
	return NO;
}

- (COEditingContext *)editingContext
{
	return [self parentContext];
}

- (COCommitTrack *)commitTrack
{
	return _commitTrack;
}

- (void)setCommitTrack: (COCommitTrack *)aTrack
{
	ASSIGN(_commitTrack, aTrack);
	[self reloadAtRevision: [[aTrack currentNode] revision]];
}

- (COSQLiteStore *)store
{
	return [_parentContext store];
}

- (id)rootObject
{
	if (_rootObject == nil)
	{
		/* -rootObjectUUID could return nil (meaning the persistent root has  
		   never been committed or has no root object)...
		   But you cannot create a persistent root without assigning it a root
		   object immediately. For -becomePersistentInContext:, -registerObject: 
		   sets the root object before the method returns. 
		   So -rootObject is never called when -rootObjectUUID could return nil. */
		ASSIGN(_rootObject, [self objectWithUUID: [self rootObjectUUID]]);
	}
	return _rootObject;
}

- (ETUUID *)rootObjectUUID
{
	if (_rootObject != nil)
	{
		return [_rootObject UUID];
	}
	else
	{
        if (_revision != nil)
        {
            ETUUID *rootUUID = [[_parentContext store]
                               rootObjectUUIDForRevisionID: [_revision revisionID]];
            return rootUUID;
        }
        else
        {
            return nil;
        }
	}
}

// NOTE: If we decide to make the method public, move it to COEditingContext
- (NSString *)defaultEntityName
{
	return @"COObject";
}

- (COObject *)objectWithUUID: (ETUUID *)uuid
{
	NILARG_EXCEPTION_TEST(uuid);
	// NOTE: We serialize UUIDs into strings in various places, this check
	// helps to intercept string objects that ought to be ETUUID objects.
	NSParameterAssert([uuid isKindOfClass: [ETUUID class]]);
	
	/* Check the object cache */

	COObject *obj = [_loadedObjects objectForKey: uuid];
    
	return obj;
}

- (NSSet *)loadedObjects
{
	return [NSSet setWithArray: [_loadedObjects allValues]];
}

- (NSSet *)loadedObjectUUIDs
{
	return [NSSet setWithArray: [_loadedObjects allKeys]];
}

- (NSSet *)loadedRootObjects
{
	NSMutableSet *loadedRootObjects = [NSMutableSet setWithSet: [self loadedObjects]];
	[[loadedRootObjects filter] isRoot];
	return loadedRootObjects;
}

- (id)loadedObjectForUUID: (ETUUID *)uuid
{
	return [_loadedObjects objectForKey: uuid];
}

- (void)cacheLoadedObject: (COObject *)object
{
	[_loadedObjects setObject: object forKey: [object UUID]];
}

- (void)discardLoadedObjectForUUID: (ETUUID *)aUUID
{
	[_loadedObjects removeObjectForKey: aUUID];
}

- (NSSet *)insertedObjects
{
	return [NSSet setWithSet: _insertedObjects];
}

- (NSSet *)updatedObjects
{
	return [NSSet setWithArray: [_updatedPropertiesByObject allKeys]];
}

- (NSSet *)updatedObjectUUIDs
{
	return [NSSet setWithArray: (id)[[[_updatedPropertiesByObject allKeys] mappedCollection] UUID]];
}


- (BOOL)isUpdatedObject: (COObject *)anObject
{
	return ([_updatedPropertiesByObject objectForKey: anObject] != nil);
}

- (NSMapTable *) updatedPropertiesByObject
{
	return _updatedPropertiesByObject;
}

- (NSSet *)deletedObjects
{
	return [NSSet setWithSet: _deletedObjects];
}

- (NSSet *)changedObjects
{
	NSSet *changedObjects = [_insertedObjects setByAddingObjectsFromSet: _deletedObjects];
	return [changedObjects setByAddingObjectsFromSet: [self updatedObjects]];
}

- (NSSet *)changedObjectUUIDs
{
	NSMutableSet *changedObjects = [NSMutableSet setWithSet: _insertedObjects];
    [changedObjects unionSet: _deletedObjects];
    [changedObjects unionSet: [self updatedObjects]];

    return (NSSet *)[[changedObjects mappedCollection] UUID];
}


- (BOOL)hasChanges
{
	return ([_updatedPropertiesByObject count] > 0
			|| [_insertedObjects count] > 0
			|| [_deletedObjects count] > 0);
}

- (void)discardAllChanges
{
	for (COObject *object in [self loadedObjects])
	{
		[self discardChangesInObject: object];
	}
	assert([self hasChanges] == NO);
}

- (void)discardChangesInObject: (COObject *)object
{
	BOOL isInsertedObject = [_insertedObjects containsObject: object];
	BOOL isUpdatedObject = ([_updatedPropertiesByObject objectForKey: object] != nil);

	if (isInsertedObject)
	{
		/* Remove the object from the cache because it has never been committed */
		[self discardLoadedObjectForUUID: [object UUID]];
	}
	if (isUpdatedObject)
	{
		/* Revert the object state back to the current persistent root revision */
		[self loadObject: object];
	}
	
	[_insertedObjects removeObject: object];
	[_updatedPropertiesByObject removeObjectForKey: object];
	[_deletedObjects removeObject: object];
}

- (void)deleteObject: (COObject *)anObject
{
	// NOTE: Deleted objects are removed from the cache on commit.
	[_deletedObjects addObject: anObject];
}

- (COObject *)insertObjectWithEntityName: (NSString *)aFullName
                                    UUID: (ETUUID *)aUUID
{
	
	ETEntityDescription *desc = [[_parentContext modelRepository] descriptionForName: aFullName];
	if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	
	Class cls = [[_parentContext modelRepository] classForEntityDescription: desc];
	/* Nil root object means the new object will be a root */
	COObject *result = [[cls alloc]
			  initWithUUID: aUUID
			  entityDescription: desc
			  context: nil];

	[result becomePersistentInContext: self];
	/* -becomePersistentInContent: calls -registerObject: that retains the object */
	[result release];

	return result;
}

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
	return [self insertObjectWithEntityName: aFullName UUID: [ETUUID UUID]];
}

- (CORevision *)commit
{
	return [self commitWithType: nil shortDescription: nil];
}

- (CORevision *)commitWithType: (NSString *)type
           shortDescription: (NSString *)shortDescription
{
	NSString *commitType = type;
	
	if (type == nil)
	{
		commitType = @"Unknown";
	}
	if (shortDescription == nil)
	{
		shortDescription = @"";
	}
	return [self commitWithMetadata: D(shortDescription, @"shortDescription", commitType, @"type")];
}

- (CORevision *)commitWithMetadata: (NSDictionary *)metadata
{
	NSArray *revs = [_parentContext commitWithMetadata: metadata
	                restrictedToPersistentRoots: A(self)];
	ETAssert([revs count] == 1);
	return [revs lastObject];
}

- (CORevision *)saveCommitWithMetadata: (NSDictionary *)metadata
{
	ETAssert(_insertedObjects != nil);
	ETAssert(_updatedPropertiesByObject != nil);
	ETAssert([[self rootObject] isRoot]);
    
	COSQLiteStore *store = [_parentContext store];
	BOOL isNewPersistentRoot = ([self revision] == nil);

    CORevisionID *revId;
    
	if (isNewPersistentRoot)
	{
		ETAssert([_insertedObjects containsObject: [self rootObject]]);

        COPersistentRootInfo *info = [store createPersistentRootWithInitialContents: self
                                                                               UUID: [self persistentRootUUID]
                                                                         branchUUID: [[self commitTrack] UUID]
                                                                           metadata: metadata];
        revId = [[info currentBranchInfo] currentRevisionID];
	}
    else
    {
        NSArray *itemUUIDs = [[self changedObjectUUIDs] allObjects];
        
        revId = [store writeContents: self
                        withMetadata: metadata
                    parentRevisionID: [_revision revisionID]
                       modifiedItems: itemUUIDs];
        
        [store setCurrentRevision: revId
                     headRevision: revId
                     tailRevision: nil
                        forBranch: [[self commitTrack] UUID]
                 ofPersistentRoot: [self persistentRootUUID]];
    }

    [self reloadPersistentRootInfo];
    
    CORevisionInfo *revInfo = [store revisionInfoForRevisionID: revId];
    
    CORevision *rev = [[CORevision alloc] initWithStore: store
                                           revisionInfo: revInfo];
    
	[self setRevision: rev];
    
    // FIXME: Re-implement
	//[[self commitTrack] didMakeNewCommitAtRevision: rev];
	
	[_insertedObjects removeAllObjects];
	[_updatedPropertiesByObject removeAllObjects];
	[_deletedObjects removeAllObjects];

	return rev;
}

- (void)registerObject: (COObject *)object
{
	NILARG_EXCEPTION_TEST(object);
	INVALIDARG_EXCEPTION_TEST(object, [[_parentContext loadedObjects] containsObject: object] == NO);

	/* If -becomePersistentInContext: receives -makePersistentRoot as argument.
	   We must be sure no root object has ever been set (committed or not). */
	if (_rootObject == nil && [self rootObjectUUID] == nil)
	{
		[self setRootObject: object];
	}

	[self cacheLoadedObject: object];
	[_insertedObjects addObject: object];
}

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
}

// FIXME: For reference...
#if 0
- (void) willLoadObject: (COObject *)obj
{
	obj->_isIgnoringDamageNotifications = YES;
	[_loadingObjects addObject: obj];
}

- (void) didLoadObject: (COObject *)obj isStillLoading: (BOOL)isStillLoading
{
	[obj awakeFromFetch];
    
	if (isStillLoading)
		return;
    
	/* Snapshot the current loaded object batch, in case -didLoad loads other
     objects, reenters this method and mutates _loadingObjects as a result. */
	NSMutableSet *loadingObjects = [_loadingObjects copy];
    
	[_loadingObjects removeAllObjects];
	[[loadingObjects mappedCollection] didLoad];
	
	// TODO: Write a test that checks unwanted damage notifications during batch loading
	for (COObject *loadedObject in loadingObjects)
	{
		[_updatedPropertiesByObject removeObjectForKey: loadedObject];
		loadedObject->_isIgnoringDamageNotifications = NO;
	}
	ETAssert([loadingObjects isEmpty] || [[self changedObjects] containsCollection: loadingObjects] == NO);
	RELEASE(loadingObjects);
    
	ETAssert([_loadingObjects isEmpty]);
}

- (void)loadObject: (COObject *)obj atRevision: (CORevision *)aRevision
{
	CORevision *loadedRev = (aRevision != nil ? aRevision : [obj revision]);
	ETAssert(loadedRev != nil);
	ETUUID *objUUID = [obj UUID];
	NSMutableSet *propertiesToFetch = [NSMutableSet setWithArray: [obj persistentPropertyNames]];
	BOOL isTriggeredLoad = ([_loadingObjects isEmpty] == NO);
	
    
	/* For CODictionary, fetch all the properties */
	if ([propertiesToFetch isEmpty])
	{
		propertiesToFetch = nil;
	}
    
	[self willLoadObject: obj];
	
	//NSLog(@"Load object %@ at %@", objUUID, loadedRev);
	//NSLog(@"Fetch properties %@", propertiesToFetch);
    
	NSDictionary *serializedValues = [loadedRev valuesForProperties: propertiesToFetch
	                                                   ofObjectUUID: objUUID
	                                                   fromRevision: nil];
    
	for (NSString *key in serializedValues)
	{
		id plist = [serializedValues objectForKey: key];
		id value = [obj valueForPropertyList: plist];
		//NSLog(@"Load property %@, unparsed %@, parsed %@", key, plist, value);
        
		[obj setSerializedValue: value forProperty: key];
	}
    
	[self didLoadObject: obj isStillLoading: isTriggeredLoad];
}

- (void)loadObject: (COObject *)obj
{
	[self loadObject: obj atRevision: nil];
}
#endif

- (void)reloadAtRevision: (CORevision *)revision
{
    // TODO: Use optimized method on the store to get a delta for more performance
    
	id<COItemGraph> aGraph = [[_parentContext store] contentsForRevisionID: [revision revisionID]];
    
    [self setItemGraph: aGraph];
    
    // FIXME: Reimplement or remove
    //[[self rootObject] didReload];
}

- (void)unload
{
	[self setRevision: nil];
	[_loadedObjects removeAllObjects];
}

- (Class)referenceClassForRootObject: (COObject *)aRootObject
{
	// TODO: When the user has selected a precise branch, just return COCommitTrack.
	return [COPersistentRoot class];
}

/** @tasknuit COItem integration */

- (NSString *)entityNameForItem: (COItem *)anItem
{
    return [anItem valueForAttribute: kCOObjectEntityNameProperty];
}

- (ETEntityDescription *)descriptionForItem: (COItem *)anItem
{
    NSString *name = [self entityNameForItem: anItem];
    
    if (name == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"COItem %@ lacks an entity name", anItem];
    }
    
    ETModelDescriptionRepository *repo = [_parentContext modelRepository];
	ETEntityDescription *desc = [repo descriptionForName: name];
    
    if (desc == nil)
    {
        desc = [repo descriptionForName: [self defaultEntityName]];
    }
    
    return desc;
}

- (COObject *)objectWithStoreItem: (COItem *)anItem
{
	NILARG_EXCEPTION_TEST(anItem);
    
	ETEntityDescription *desc = [self descriptionForItem: anItem];
	Class objClass = [[_parentContext modelRepository] classForEntityDescription: desc];
    
	COObject *obj = [[objClass alloc] initWithUUID: [anItem UUID]
                                 entityDescription: desc
                                           context: self];
    [obj becomePersistentInContext: self];
    [obj setStoreItem: anItem];
	[obj release];
    
    [self addCachedOutgoingRelationshipsForObject: obj];
    
	return obj;
}

/** @taskunit COItemGraph protocol */

- (ETUUID *) rootItemUUID
{
    return [_rootObject UUID];
}

/**
 * Returns immutable item
 */
- (COItem *) itemForUUID: (ETUUID *)aUUID
{
    COObject *object = [self objectWithUUID: aUUID];

    COItem *item = [object storeItem];
    
    return item;
}

- (NSArray *) itemUUIDs
{
    // FIXME: This API should return all UUIDs, not just loaded ones.
    return [_loadedObjects allKeys];
}

/**
 * Insert or update an item.
 */
- (void) addItem: (COItem *)item markAsInserted: (BOOL)markInserted
{
    NSParameterAssert(item != nil);
    
    ETUUID *uuid = [item UUID];
    COObject *currentObject = [_loadedObjects objectForKey: uuid];
    
    if (currentObject == nil)
    {
        currentObject = [self objectWithStoreItem: item];

//        if (markInserted)
//        {
//            [
//        }
    }
    else
    {
        [self removeCachedOutgoingRelationshipsForObject: currentObject];
        [currentObject setStoreItem: item];
        [self addCachedOutgoingRelationshipsForObject: currentObject];
//        [modifiedObjects_ addObject: uuid];
    }
}

/**
 * Insert or update an item.
 */
- (void) addItem: (COItem *)anItem
{
    [self addItem: anItem markAsInserted: YES];
}

/** @taskunit Setting entire graph */

- (void) setItemGraph: (id <COItemGraph>)aGraph
{
    for (ETUUID *uuid in [aGraph itemUUIDs])
    {
        [self addItem: [aGraph itemForUUID: uuid] markAsInserted: NO];
    }
    
    COObject *newRoot = [self objectWithUUID: [aGraph rootItemUUID]];
    assert(newRoot != nil);
    ASSIGN(_rootObject, newRoot);
}

/** @taskunit Persistent root info */

- (COPersistentRootInfo *) persistentRootInfo
{
    return _info;
}

- (void) reloadPersistentRootInfo
{
    COPersistentRootInfo *newInfo = [[self store] persistentRootWithUUID: [self persistentRootUUID]];
    if (newInfo != nil)
    {
        ASSIGN(_info, newInfo);
    }
}

- (CORevision *)revision
{
    return _revision;
}

- (void) setRevision:(CORevision *)revision
{
    ASSIGN(_revision, revision);
    [self reloadAtRevision: _revision];
}

@end
