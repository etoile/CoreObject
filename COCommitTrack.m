/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COCommitTrack.h"
#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COStore.h"
#import "COObject.h"
#import "CORevision.h"
#import "FMDatabase.h"

#define CACHE_AMOUNT 30

@implementation COCommitTrack

@synthesize UUID, label, persistentRoot, isCopy, isMainBranch;

/* Both root object and revision are lazily retrieved by the persistent root. 
   Until the loaded revision is known, it is useless to cache track nodes. */
- (id)initWithUUID: (ETUUID *)aUUID editingContext: (COPersistentRoot *)aContext;
{
	NILARG_EXCEPTION_TEST(aUUID);
	NSParameterAssert([aUUID isKindOfClass: [ETUUID class]]);
	NILARG_EXCEPTION_TEST(aContext);

	if ([[aContext parentContext] store] == nil)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Cannot load commit track for %@ which does not have a store or editing context", aContext];
	}

	SUPERINIT;

	ASSIGN(UUID, aUUID);
	/* The persistent root retains us */
	persistentRoot = aContext;

	[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
	                                                    selector: @selector(currentNodeDidChangeInStore:) 
	                                                        name: COStoreDidChangeCurrentNodeOnTrackNotification 
	                                                      object: [[self UUID] stringValue]];

	return self;	
}

- (void)dealloc
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
	DESTROY(UUID);
	DESTROY(parentTrack);
	DESTROY(label);
	[super dealloc];
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [COCommitTrack class]])
	{
		return ([UUID isEqual: [rhs UUID]]
			&& [[persistentRoot persistentRootUUID] isEqual: [[rhs persistentRoot] persistentRootUUID]]);
	}
	return NO;
}

- (BOOL)isBranch
{
	return ([self isCopy] == NO && [self parentTrack] != nil);
}

- (NSString *)label
{
	return [[[self persistentRoot] store] nameForCommitTrackUUID: [self UUID]];
}

- (CORevision *)parentRevision
{
	return [[[self persistentRoot] store] parentRevisionForCommitTrackUUID: [self UUID]];
}

- (COCommitTrack *)parentTrack
{
	return [[[COCommitTrack alloc] initWithUUID: [[self parentRevision] trackUUID]
	                             editingContext: [self persistentRoot]] autorelease];
}

- (COCommitTrack *)makeBranchWithLabel: (NSString *)aLabel
{
	return [self makeBranchWithLabel: aLabel atRevision: [[self persistentRoot] revision]];
}

- (COCommitTrack *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev
{
	NILARG_EXCEPTION_TEST(aRev);

	ETUUID *branchUUID = [ETUUID UUID];
	COStore *store = [[self persistentRoot] store];
	CORevision *rev = [store createCommitTrackWithUUID: branchUUID
	                                              name: aLabel
	                                    parentRevision: aRev
	                                    rootObjectUUID: [[self persistentRoot] rootObjectUUID]
	                                persistentRootUUID: [[self persistentRoot] persistentRootUUID]
	                               isNewPersistentRoot: NO];

	[[[self persistentRoot] parentContext] didCommitRevision: rev];
	
	return [[[COCommitTrack alloc] initWithUUID: branchUUID
								 editingContext: [self persistentRoot]] autorelease];

}

- (COCommitTrack *)makeCopyFromRevision: (CORevision *)aRev
{
	NILARG_EXCEPTION_TEST(aRev);
	
	ETUUID *branchUUID = [ETUUID UUID];
	COStore *store = [[self persistentRoot] store];
	CORevision *rev = [store createCommitTrackWithUUID: branchUUID
	                                              name: nil
	                                    parentRevision: aRev
	                                    rootObjectUUID: [[self persistentRoot] rootObjectUUID]
	                                persistentRootUUID: [ETUUID UUID]
	                               isNewPersistentRoot: YES];

	[[[self persistentRoot] parentContext] didCommitRevision: rev];
	
	return [[[COCommitTrack alloc] initWithUUID: branchUUID
								 editingContext: [self persistentRoot]] autorelease];
}

- (BOOL)mergeChangesFromTrack: (COCommitTrack *)aSourceTrack
{
	return NO;
}

- (BOOL)mergeChangesFromRevision: (CORevision *)startRev
							  to: (CORevision *)endRev
						 ofTrack: (COCommitTrack *)aSourceTrack
{
	return NO;
}

- (BOOL)mergeChangesFromRevisionSet: (NSSet *)revs
							ofTrack: (COCommitTrack *)aSourceTrack
{
	return NO;
}

- (BOOL)isOurStoreForNotification: (NSNotification *)notif
{
	NSString *storeUUIDString = [[notif userInfo] objectForKey: kCOStoreUUIDStringKey];
	return [storeUUIDString isEqual: [[[[self persistentRoot] store] UUID] stringValue]];
}

/* This method is called back through distributed notifications in various cases:
   - a commit calling -addRevision:toTrackUUID:
   - a selective undo or redo (this is the same than the previous case since 
     this results in a new commit)
   - an undo or redo calling -undoOnTrackUUID:
   In each case, the track posting the notification can be either the receiver 
   or another instance (in the same or another process) bearing the same UUID.
   For an undo/redo, when the track triggering the notification is the receiver, 
   then we return immediately to prevent updating the currentNodeIndex already 
   updated in -undo and -redo methods.
   When the receiver is not the track posting the notification, the two track 
   instances are not located in the same editing context. */
- (void)currentNodeDidChangeInStore: (NSNotification *)notif
{
	/* Paranoid check in case something goes wrong and a core object UUID
	   appear in multiple stores.
	   For now, a core object UUID is bound to a single store. Hence a commit
	   track UUID is never in use accross multiple stores (using distinct UUIDs).  */
	if ([self isOurStoreForNotification: notif])
		return;

	NSParameterAssert([[[self UUID] stringValue] isEqual: [notif object]]);

	COEditingContext *context = [[self persistentRoot] parentContext];
	int64_t revNumber = [[[notif userInfo] objectForKey: kCONewCurrentNodeRevisionNumberKey] longLongValue];
	BOOL isBasicUndoRedoFromCurrentContext = (revNumber == [[[self currentNode] revision] revisionNumber]);
	BOOL isCommitFromCurrentContext = (revNumber == [context latestRevisionNumber]);

	/* Distributed notifications are ignored in the cases below: 
	   - -undo or -redo was invoked on the receiver
	   - a tracked object editing context commit (see also -didMakeNewAtRevision:)
	 
	   This method updates the track nodes in the cases below:
	   - -undo or -redo was invoked on another receiver instance in some other editing context
	   - a commit on another tracked object instance in some other editing context
	   - a selective undo
	
	   For each track UUID, this method requires that a single track instance 
	   exists per editing context. */
	if (isBasicUndoRedoFromCurrentContext || isCommitFromCurrentContext)
		return;

	COTrackNode *oldCurrentNode = RETAIN([self currentNode]);

	[self reloadNodes];

	// FIXME: The currentNodeIndex assertion requires that distributed 
	// notifications to be delivered (but the notification center might drop 
	// some notifications under heavy load according to Cocoa API doc)
	assert([[self currentNode] isEqual: oldCurrentNode] == NO);
	assert([self currentNode] != nil);
	assert(revNumber == [[[self currentNode] revision] revisionNumber]);

	/* For a commit in the receiver editing context, no reloading occurs 
	   because the tracked object state matches the revision */
	[[self persistentRoot] reloadAtRevision: [[self currentNode] revision]];

	[self didUpdate];
	RELEASE(oldCurrentNode);
}

- (BOOL)needsReloadNodes: (NSArray *)currentLoadedNodes
{
	return (isLoaded == NO);
}

- (NSArray *)allNodesAndCurrentNodeIndex: (NSUInteger *)aNodeIndex
{
	// NOTE: For a new track, -[COSQLStore isTrackUUID:] would return NO
	
	COStore *store = [[self persistentRoot] store];
	return [store nodesForTrackUUID: [self UUID]
	                    nodeBuilder: self
	               currentNodeIndex: aNodeIndex
	                  backwardLimit: NSUIntegerMax
	                   forwardLimit: NSUIntegerMax];
}

- (NSArray *)provideNodesAndCurrentNodeIndex: (NSUInteger *)aNodeIndex
{
	return [self allNodesAndCurrentNodeIndex: aNodeIndex];
}

- (void)didReloadNodes
{
	isLoaded = YES;

	if ([self currentNode] == nil)
		return;
	
	CORevision *currentRev =
		[[[self persistentRoot] store] currentRevisionForTrackUUID: [self UUID]];
	
	ETAssert([[[self currentNode] revision] isEqual: currentRev]);
}

- (void)setCurrentNode: (COTrackNode *)aNode
{
	INVALIDARG_EXCEPTION_TEST(aNode, [aNode track] == self);

	NSUInteger nodeIndex = [[self loadedNodes] indexOfObject: aNode];

	if (nodeIndex == NSNotFound)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Cannot find %@ on %@ currently", aNode, self];
	}
	currentNodeIndex = nodeIndex;

	assert([[self currentNode] isEqual: aNode]);

	[[[self persistentRoot] store] setCurrentRevision: [aNode revision]
	                                     forTrackUUID: [self UUID]];
	[[self persistentRoot] reloadAtRevision: [aNode revision]];
	[self didUpdate];
}

- (void)undo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot undo object %@ which does not have any commits", [self persistentRoot]];
	}
	/* If -canUndo returns YES, before returning it loads some previous nodes 
	   to ensure currentNodeIndex is not zero and can be decremented */
	if ([self canUndo] == NO)
	{
		return;
	}

	/* We must update the current node before calling -undoOnTrackUUID: because
	   this last method posts a distributed notification that might be delivered 
	   before returning (at least on GNUstep, but not Mac OS X where immediate 
	   delivery behavior differs slightly). */
	currentNodeIndex--;
	// Check to make sure new node was cached
	NSAssert(currentNodeIndex != NSNotFound 
		&& ![[NSNull null] isEqual: [[self loadedNodes] objectAtIndex: currentNodeIndex]],
		@"Record undone to is cached");

	CORevision *currentRevision = [[[self persistentRoot] store] undoOnTrackUUID: [self UUID]];

	// TODO: Reset object state to old object.
	[[self persistentRoot] reloadAtRevision: currentRevision];

	[self didUpdate];
}

- (void)redo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot redo object %@ which does not have any commits", [self persistentRoot]];
	}
	/* If -canRedo returns YES, before returning it loads some next nodes 
	   to ensure currentNodeIndex is not zero and can be incremented */
	if ([self canRedo] == NO)
	{
		return;
	}

	/* We must update the current node before calling -redoOnTrackUUID: because
	   this last method posts a distributed notification that might be delivered 
	   before returning (at least on GNUstep, but not Mac OS X where immediate 
	   delivery behavior differs slightly). */
	currentNodeIndex++;
	// Check to make sure new node was cached
	NSAssert([[self loadedNodes] count] > currentNodeIndex 
		&& ![[NSNull null] isEqual: [[self loadedNodes] objectAtIndex: currentNodeIndex]],
		@"Record redone to is cached");

	CORevision *currentRevision = [[[self persistentRoot] store] redoOnTrackUUID: [self UUID]];

	// TODO: Reset object state to old object.
	[[self persistentRoot] reloadAtRevision: currentRevision];

	[self didUpdate];
}

- (void)undoNode: (COTrackNode *)aNode
{
	BOOL useCommitTrackUndo = ([[[self currentNode] previousNode] isEqual: aNode]);
	BOOL useCommitTrackRedo = ([[[self currentNode] nextNode] isEqual: aNode]);

	if (useCommitTrackUndo)
	{
		[self undo];
	}
	else if (useCommitTrackRedo)
	{
		[self redo];
	}
	else
	{
		[self selectiveUndoWithRevision: [aNode revision] 
		               inEditingContext: [[self persistentRoot] parentContext]];
	}
}

- (void)didMakeNewCommitAtRevision: (CORevision *)revision
{
	NSParameterAssert(revision != nil);
	NSParameterAssert([revision commitNodeID] != NSIntegerMax);

	COTrackNode *newNode = [COTrackNode nodeWithID: [revision commitNodeID] revision: revision onTrack: self];
	/* At this point, revision is the max revision for the commit track */
	BOOL isFirstRevision = ([revision baseRevision] == nil);

	/* Prevent -loadedNodes to access the store */
	if (isFirstRevision)
	{
		isLoaded = YES;
	}

	BOOL isTipNodeCached = (isFirstRevision
		|| [[[[self loadedNodes] lastObject] revision] isEqual: [revision baseRevision]]);

	if (isTipNodeCached == NO)
	{
		[self reloadNodes];
	}

	[[self loadedNodes] addObject: newNode];
	currentNodeIndex = [[self loadedNodes] count] - 1;

	[self didUpdate];
}

@end
