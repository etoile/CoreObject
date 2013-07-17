/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#if 0

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

#pragma mark -
#pragma mark Listing Persistent Objects

- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID
{
	return [self objectUUIDsForCommitTrackUUID: aUUID atRevision: nil];
}

- (NSSet *)objectUUIDsForCommitTrackUUID: (ETUUID *)aUUID atRevision: (CORevision *)revision
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

#pragma mark -
#pragma mark Root Objects

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

- (ETUUID *)rootObjectUUIDForObjectUUID: (ETUUID *)aUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

#pragma mark -
#pragma mark Persistent Roots

- (BOOL)isPersistentRootUUID: (ETUUID *)aUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}

- (NSSet *)persistentRootUUIDs
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
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

- (ETUUID *)rootObjectUUIDForPersistentRootUUID: (ETUUID *)aPersistentRootUUID
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

- (CORevision *)deletePersistentRootForUUID: (ETUUID *)aPersistentRootUUID
                                   eraseNow: (BOOL)eraseNow
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

#pragma mark -
#pragma mark Committing Changes 

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

#pragma mark -
#pragma mark Accessing Revisions

- (CORevision *)latestRevision
{
	return [self revisionWithRevisionNumber: [self latestRevisionNumber]];
}

- (int64_t)latestRevisionNumber
{
	[self doesNotRecognizeSelector: _cmd];
	return 0;
}

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

#pragma mark -
#pragma mark Full-text Search

- (NSArray*)resultDictionariesForQuery: (NSString*)query
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

#pragma mark -
#pragma mark Managing Commit Tracks (Low-Level API)

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

- (CORevision *)createCommitTrackWithUUID: (ETUUID *)aBranchUUID
                                     name: (NSString *)aBranchName
                           parentRevision: (CORevision *)aRevision
				           rootObjectUUID: (ETUUID *)aRootObjectUUID
                       persistentRootUUID: (ETUUID *)aPersistentRootUUID
                      isNewPersistentRoot: (BOOL)isNewPersistentRoot
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (CORevision *)parentRevisionForCommitTrackUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSArray *)parentTrackUUIDsForCommitTrackUUID: (ETUUID *)aTrackUUID
{
	NSMutableArray *UUIDs = [NSMutableArray array];
	ETUUID *trackUUID = aTrackUUID;
	
	// TODO: Optimize using a single query if needed
	while ((trackUUID = [[self parentRevisionForCommitTrackUUID: trackUUID] trackUUID]) != nil)
	{
		[UUIDs insertObject: trackUUID atIndex: 0];
	}
	
	return UUIDs;
}

- (NSString *)nameForCommitTrackUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return @"";
}

- (CORevision *)maxRevision: (int64_t)maxRevNumber forCommitTrackUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

#pragma mark -
#pragma mark Managing Tracks (Low-Level API)

- (CORevision *)currentRevisionForTrackIndex: (NSNumber *)aTrackIndex
                               currentNodeID: (int64_t *)currentNodeID
                              previousNodeID: (int64_t *)previousNodeID
                                  nextNodeID: (int64_t *)nextNodeID
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSArray *)nodesForTrackUUID: (ETUUID *)aTrackUUID
                   nodeBuilder: (id <COTrackNodeBuilder>)aNodeBuilder
              currentNodeIndex: (NSUInteger *)currentNodeIndex
                 backwardLimit: (NSUInteger)backward
                  forwardLimit: (NSUInteger)forward
{
	// TODO: Move some core logic here
	return nil;
}

- (id)makeNodeWithID: (int64_t)aNodeID revision: (CORevision *)aRevision
{
	return aRevision;
}

- (CORevision *) currentRevisionForTrackUUID: (ETUUID *)aTrackUUID
{
	NSArray *revs = [self nodesForTrackUUID: aTrackUUID
	                            nodeBuilder: (id <COTrackNodeBuilder>)self
	                       currentNodeIndex: NULL
	                          backwardLimit: 0
	                           forwardLimit: 0];
	return [revs firstObject];
}

- (void)setCurrentRevision: (CORevision *)newRev 
              forTrackUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
}

- (int64_t)addRevision: (CORevision *)newRevision toTrackUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
	return 0;
}

- (void)deleteTrackForUUID: (ETUUID *)aTrackUUID
{
	[self doesNotRecognizeSelector: _cmd];
}

- (CORevision *)undoOnTrackUUID: (ETUUID *)aTrackUUID;
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (CORevision *)redoOnTrackUUID: (ETUUID *)aTrackUUID;
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

#pragma mark -

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

#endif
