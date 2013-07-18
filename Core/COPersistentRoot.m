/*
	Copyright (C) 2012 Quentin Mathe
 
	Author:  Quentin Mathe <quentin.mathe@gmail.com>, 
	         Eric Wasylishen <ewasylishen@gmail.com>
	Date:  November 2012
	License:  Modified BSD  (see COPYING)
 */

#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COEditingContext.h"
#import "COError.h"
#import "COItem.h"
#import "COObject.h"
#import "COObjectGraphContext.h"
#import "CORelationshipCache.h"
#import "CORevision.h"
#import "COSerialization.h"
#import "COSQLiteStore.h"

@implementation COPersistentRoot

@synthesize parentContext = _parentContext,
	commitTrack = _commitTrack, objectGraph = _objectGraph;

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
        _info.mainBranchUUID = branchInfo.UUID;
        _info.branchForUUID = D(branchInfo, branchInfo.UUID);
    }
    else
    {
        ASSIGN(_info, info);
    }

	_parentContext = aCtxt;
	if ([_parentContext store] != nil)
	{
		_commitTrack = [[COBranch alloc] initWithUUID: _info.mainBranchUUID persistentRoot: self];
	}
	
    CORevisionID *revId = [[_info mainBranchInfo] currentRevisionID];
    if (revId != nil)
    {
        // FIXME: Ugly to have a store access here. Perhaps CORevision should do it lazily?
        CORevisionInfo *revInfo = [[_parentContext store] revisionInfoForRevisionID: revId];
        
        _revision = [[CORevision alloc] initWithStore: [_parentContext store]
                                         revisionInfo: revInfo];
    }

    _objectGraph = [[COObjectGraphContext alloc] initWithPersistentRoot: self];
    
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
	DESTROY(_revision);
    DESTROY(_objectGraph);
	[super dealloc];
}

#if 0
- (NSString *)description
{
	// TODO: Improve the indenting
	NSString *desc = [D([self insertedObjects], @"Inserted Objects",
	                    [self deletedObjects], @"Deleted Objects",
	                    _updatedPropertiesByObject, @"Updated Objects") description];
	/* For Mac OS X, see http://www.cocoabuilder.com/archive/cocoa/197297-who-broke-nslog-on-leopard.html */
	return [desc stringByReplacingOccurrencesOfString: @"\\n" withString: @"\n"];
}
#endif

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

- (COBranch *)commitTrack
{
	return _commitTrack;
}

- (void)setCommitTrack: (COBranch *)aTrack
{
	ASSIGN(_commitTrack, aTrack);
	[self reloadAtRevision: [aTrack currentRevision]];
}

- (COSQLiteStore *)store
{
	return [_parentContext store];
}

- (id)rootObject
{
	return [_objectGraph rootObject];
}

- (void)setRootObject: (COObject *)aRootObject
{
	[_objectGraph setRootObject: aRootObject];
}

- (ETUUID *)rootObjectUUID
{
	return [_objectGraph rootItemUUID];
}

- (COObject *)objectWithUUID: (ETUUID *)uuid
{
	return [_objectGraph objectWithUUID: uuid];
}

- (NSSet *)loadedObjects
{
    return [NSSet setWithArray: [_objectGraph allObjects]];
}

- (NSSet *)loadedObjectUUIDs
{
	return [NSSet setWithArray: [_objectGraph itemUUIDs]];
}

- (NSSet *)loadedRootObjects
{
	NSMutableSet *loadedRootObjects = [NSMutableSet setWithSet: [self loadedObjects]];
	[[loadedRootObjects filter] isRoot];
	return loadedRootObjects;
}

- (id)loadedObjectForUUID: (ETUUID *)uuid
{
	return [_objectGraph objectWithUUID: uuid];
}

- (void)discardLoadedObjectForUUID: (ETUUID *)aUUID
{
    NSLog(@"-discardLoadedObjectForUUID: deprecated and has no effect");
}

- (NSSet *)insertedObjects
{
	return [_objectGraph insertedObjects];
}

- (NSSet *)updatedObjects
{
	return [_objectGraph updatedObjects];
}

- (NSSet *)updatedObjectUUIDs
{
	return [NSSet setWithArray: (id)[[[self updatedObjects] mappedCollection] UUID]];
}

- (BOOL)isUpdatedObject: (COObject *)anObject
{
	return [[self updatedObjects] containsObject: anObject];
}

- (NSMapTable *) updatedPropertiesByObject
{
	return [_objectGraph updatedPropertiesByObject];
}

// TODO: Deprecated; remove.
- (NSSet *)deletedObjects
{
	return [NSSet set];
}

- (NSSet *)changedObjects
{
    return [_objectGraph changedObjects];
}

- (NSSet *)changedObjectUUIDs
{
    return (NSSet *)[[[self changedObjects] mappedCollection] UUID];
}


- (BOOL)hasChanges
{
	return [[self changedObjects] count] > 0;
}

- (void)discardAllChanges
{
	for (COObject *object in [self changedObjects])
	{
		[self discardChangesInObject: object];
	}
	assert([self hasChanges] == NO);
}

- (void)discardChangesInObject: (COObject *)object
{
    if (_revision != nil)
    {
        CORevisionID *revid = [_revision revisionID];
        
        COItem *item = [[self store] item: [object UUID]
                             atRevisionID: revid];
        
        [_objectGraph addItem: item];        
        [_objectGraph clearChangeTrackingForObject: object];
    }
}

- (void)deleteObject: (COObject *)anObject
{
    NSLog(@"deleteObject() is deprecated and has no effect");
}

- (COObject *)insertObjectWithEntityName: (NSString *)aFullName
                                    UUID: (ETUUID *)aUUID
{
	return [_objectGraph insertObjectWithEntityName: aFullName
                                               UUID: aUUID];
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
	ETAssert([[self rootObject] isRoot]);
    
	COSQLiteStore *store = [_parentContext store];
	BOOL isNewPersistentRoot = ([self revision] == nil);

    CORevisionID *revId;
    
	if (isNewPersistentRoot)
	{
		ETAssert([[self insertedObjects] containsObject: [self rootObject]]);

        COPersistentRootInfo *info = [store createPersistentRootWithInitialContents: _objectGraph
                                                                               UUID: [self persistentRootUUID]
                                                                         branchUUID: [[self commitTrack] UUID]
                                                                           metadata: metadata
                                                                              error: NULL];
        revId = [[info mainBranchInfo] currentRevisionID];
	}
    else
    {
        NSArray *itemUUIDs = [[self changedObjectUUIDs] allObjects];
        
        revId = [store writeContents: _objectGraph
                        withMetadata: metadata
                    parentRevisionID: [_revision revisionID]
                       modifiedItems: itemUUIDs
                               error: NULL];
        
        int64_t changeCount = _info.changeCount;
        
        [store setCurrentRevision: revId
                     headRevision: revId
                     tailRevision: nil
                        forBranch: [[self commitTrack] UUID]
                 ofPersistentRoot: [self persistentRootUUID]
               currentChangeCount: &changeCount
                            error: NULL];
    }

    [self reloadPersistentRootInfo];
    
    CORevisionInfo *revInfo = [store revisionInfoForRevisionID: revId];
    
    CORevision *rev = [[CORevision alloc] initWithStore: store
                                           revisionInfo: revInfo];
    
	ASSIGN(_revision, rev);
    
    // FIXME: Re-implement
	//[[self commitTrack] didMakeNewCommitAtRevision: rev];
	
	[_objectGraph clearChangeTracking];

	return rev;
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
    NSParameterAssert(revision != nil);
    
    // TODO: Use optimized method on the store to get a delta for more performance
    
	id<COItemGraph> aGraph = [[_parentContext store] contentsForRevisionID: [revision revisionID]];
    
    [_objectGraph setItemGraph: aGraph];
    
    // FIXME: Reimplement or remove
    //[[self rootObject] didReload];
}

- (void)unload
{
	NSLog(@"-unload deprecated and has no effect");
}

- (Class)referenceClassForRootObject: (COObject *)aRootObject
{
	// TODO: When the user has selected a precise branch, just return COCommitTrack.
	return [COPersistentRoot class];
}

/** @taskunit Persistent root info */

- (COPersistentRootInfo *) persistentRootInfo
{
    return _info;
}

- (void) reloadPersistentRootInfo
{
    COPersistentRootInfo *newInfo = [[self store] persistentRootInfoForUUID: [self persistentRootUUID]];
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
