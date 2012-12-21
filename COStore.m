#import "COStore.h"
#import "FMDatabase.h"


@implementation COStore

- (id)initWithURL: (NSURL *)aURL
{
	if ([self isMemberOfClass: [COStore class]])
	{
		[NSException raise: NSInternalInconsistencyException
					format: _(@"%@ is an abstract class and must never be instantiated."
							  "Subclasses such as COSQLStore must be used.")];
		[self release];
		return nil;
	}
	SUPERINIT;
	url = [aURL retain];
	commitObjectForID = [[NSMutableDictionary alloc] init];
	return self;
}

- (void)dealloc
{
	[commitObjectForID release];
	[url release];
	[super dealloc];
}

- (NSURL *)URL
{
	return url;
}

- (ETUUID *)UUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSDictionary *)metadata
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void)setMetadata: (NSDictionary *)plist
{
	[self doesNotRecognizeSelector: _cmd];
}

- (BOOL)isRootObjectUUID: (ETUUID *)uuid
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}

- (NSSet *)rootObjectUUIDs
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID atRevision: (CORevision *)revision
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (ETUUID *)rootObjectUUIDForObjectUUID: (ETUUID *)aUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (ETUUID *)rootObjectUUIDForPersistentRootUUID: (ETUUID *)aPersistentRootUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (BOOL)isPersistentRootUUID: (ETUUID *)aUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}

- (ETUUID *)persistentRootUUIDForCommitTrackUUID: (ETUUID *)aTrackUUId
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (ETUUID *)mainBranchUUIDForPersistentRootUUID: (ETUUID *)aUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (ETUUID *)persistentRootUUIDForRootObjectUUID: (ETUUID *)aUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void)insertPersistentRootUUID: (ETUUID *)aPersistentRootUUID
				 commitTrackUUID: (ETUUID *)aMainBranchUUID
				  rootObjectUUID: (ETUUID *)aRootObjectUUID
{
	[self doesNotRecognizeSelector: _cmd];
}

/* Committing Changes */

- (void)beginCommitWithMetadata: (NSDictionary *)metadata
			 persistentRootUUID: (ETUUID *)aPersistentRootUUID
				commitTrackUUID: (ETUUID *)aTrackUUID
                   baseRevision: (CORevision *)baseRevision
				 
{
	// TODO: Move some core logic here
}

- (void)beginChangesForObjectUUID: (ETUUID*)object
{
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	if (objectInProgress != nil)
	{
		[NSException raise: NSGenericException format: @"Finish the current object first"];
	}
	objectInProgress = [object retain];
}

- (void)setValue: (id)value
	 forProperty: (NSString*)property
		ofObject: (ETUUID*)object
	 shouldIndex: (BOOL)shouldIndex
{
	// TODO: Move some core logic here
}

- (void)finishChangesForObjectUUID: (ETUUID*)object
{
	if (commitInProgress == nil)
	{
		[NSException raise: NSGenericException format: @"Start a commit first"];
	}
	if (![objectInProgress isEqual: object])
	{
		[NSException raise: NSGenericException format: @"Object in progress doesn't match"];
	}
	if (!hasPushedChanges)
	{
		// TODO: Turn on this exception
		//[NSException raise: NSGenericException format: @"Push changes before finishing the commit"];
	}
	[objectInProgress release];
	objectInProgress = nil;
	hasPushedChanges = NO;
}

- (CORevision *)finishCommit
{
	// TODO: Move some core logic here
	return nil;
}

/* Accessing History Graph and Committed Changes */

- (CORevision *)revisionWithRevisionNumber: (int64_t)anID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSArray *)revisionsForObjectUUIDs: (NSSet *)uuids
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

/* Full-text Search */

- (NSArray*)resultDictionariesForQuery: (NSString*)query
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

/* Revision history */

- (int64_t)latestRevisionNumber
{
	[self doesNotRecognizeSelector: _cmd];
	return 0;
}

- (void)didChangeCurrentNodeFromRevision: (CORevision *)oldRev 
                                  toNode: (NSNumber *)newNode 
                                revision: (CORevision *)newRev
                             onTrackUUID: (ETUUID *)aTrackUUID
{
	// TODO: Should we compute kCONewCurrentNodeIndexKey to resync tracks more easily...
	NSDictionary *infos = D(newNode, kCONewCurrentNodeIDKey, 
		[NSNumber numberWithLongLong: [newRev revisionNumber]], kCONewCurrentNodeRevisionNumberKey, 
		[NSNumber numberWithLongLong: [oldRev revisionNumber]], kCOOldCurrentNodeRevisionNumberKey, 
		[[self UUID] stringValue], kCOStoreUUIDStringKey); 
	[(id)[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStoreDidChangeCurrentNodeOnTrackNotification 
	                                                               object: [aTrackUUID stringValue]
	                                                             userInfo: infos
	                                                   deliverImmediately: YES];
}

- (CORevision *)createCommitTrackForRootObjectUUID: (NSNumber *)uuidIndex
                                          revision: (CORevision *)aRevision
                                     currentNodeId: (int64_t *)pCurrentNodeId
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (CORevision *)createCommitTrackForRootObjectUUID: (NSNumber *)uuidIndex
                                     currentNodeId: (int64_t *)pCurrentNodeId
{
	return [self createCommitTrackForRootObjectUUID: uuidIndex revision: nil currentNodeId: pCurrentNodeId];
}

- (CORevision *)commitTrackForRootObject: (NSNumber *)objectUUIDIndex
                             currentNode: (int64_t *)pCurrentNode
                            previousNode: (int64_t *)pPreviousNode
                                nextNode: (int64_t *)pNextNode
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

/**
  * Load the revision numbers for a root object along its commit track.
  * The resulting array of revisions will be (forward + backward + 1) elements
  * long, with the revisions ordered from oldest to last.
  * revision may optionally be nil to find a commit track for an object
  * (or create one if it doesn't exist).
  * 
  * The current implementation is quite inefficient in that it hits the
  * database (forward + backward + 1) time, once for each
  * revision on the commit track.
 */
- (NSArray *)revisionsForTrackUUID: (ETUUID *)objectUUID
                  currentNodeIndex: (NSUInteger *)currentNodeIndex
                     backwardLimit: (NSUInteger)backward
                      forwardLimit: (NSUInteger)forward
{
	// TODO: Move some core logic here
	return nil;
}

- (CORevision *) currentRevisionForTrackUUID: (ETUUID *)aTrackUUID
{
	NSArray *revs = [self revisionsForTrackUUID: aTrackUUID
	                           currentNodeIndex: NULL
	                              backwardLimit: 0
	                               forwardLimit: 0];
	assert([revs count] == 1);
	return [revs firstObject];
}

- (void)setCurrentRevision: (CORevision *)newRev 
              forTrackUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
}

// TODO: Or should we name it -pushRevision:onTrackUUID:...
- (void)addRevision: (CORevision *)newRevision toTrackUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
}

- (CORevision *)undoOnCommitTrack: (ETUUID *)rootObjectUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (CORevision *)redoOnCommitTrack: (ETUUID *)rootObjectUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (CORevision *)maxRevision: (int64_t)maxRevNumber forRootObjectUUID: (ETUUID *)uuid
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (BOOL)isTrackUUID: (ETUUID *)uuid
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}

@end

NSString *COStoreDidChangeCurrentNodeOnTrackNotification = @"COStoreDidChangeCurrentNodeOnTrackNotification";
NSString *kCONewCurrentNodeIDKey = @"kCONewCurrentNodeIDKey";
NSString *kCONewCurrentNodeRevisionNumberKey = @"kCONewCurrentNodeRevisionNumberKey";
NSString *kCOOldCurrentNodeRevisionNumberKey = @"kCOOldCurrentNodeRevisionNumberKey";
NSString *kCOStoreUUIDStringKey = @"kCOStoreUUIDStringKey";

@implementation CORecord

- (id)initWithDictionary: (NSDictionary *)aDict
{
	SUPERINIT;
	ASSIGN(dictionary, aDict);
	return self;
}

- (void)dealloc
{
	DESTROY(dictionary);
	[super dealloc];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		[dictionary allKeys]];
}

- (id) valueForProperty: (NSString *)aKey
{
	id value = [dictionary objectForKey: aKey];

	if (value == nil)
	{
		value = [super valueForProperty: aKey];
	}
	return value;
}

- (BOOL) setValue: (id)value forProperty: (NSString *)aKey
{
	if ([[dictionary allKeys] containsObject: aKey])
	{
		if ([dictionary isMutable])
		{
			[(NSMutableDictionary *)dictionary setObject: value forKey: aKey];
			return YES;
		}
		else
		{
			return NO;
		}
	}
	return [super setValue: value forProperty: aKey];
}

@end
