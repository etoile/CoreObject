/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COCommitTrack.h"
#import "COEditingContext.h"
#import "COPersistentRootEditingContext.h"
#import "COStore.h"
#import "COObject.h"
#import "CORevision.h"
#import "FMDatabase.h"

#define CACHE_AMOUNT 30

@implementation COCommitTrack

@synthesize UUID, editingContext, label, parentTrack, isCopy, isMainBranch;

- (id)initWithUUID: (ETUUID *)aUUID editingContext: (COPersistentRootEditingContext *)aContext;
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(aContext);

	if ([[aContext parentContext] store] == nil)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Cannot load commit track for %@ which does not have a store or editing context", aContext];
	}

	self = [super initWithTrackedObjects: nil];
	if (self == nil)
		return nil;

	ASSIGN(UUID, aUUID);
	/* The persistent root retains us */
	editingContext = aContext;

	// TODO: Might be not a good idea to cache nodes so soon
	if ([[self trackedObject] revision] != nil)
	{
		[self cacheNodesForward: CACHE_AMOUNT backward: CACHE_AMOUNT];
	}

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
			&& [[editingContext persistentRootUUID] isEqual: [[rhs editingContext] persistentRootUUID]]);
	}
	return NO;
}

- (COObject *)trackedObject
{
	return [editingContext rootObject];
}

- (BOOL)isBranch
{
	return ([self isCopy] == NO && [self parentTrack] != nil);
}

- (CORevision *)parentRevision
{
	return nil;
}

- (COCommitTrack *)makeBranchWithLabel: (NSString *)aLabel
{
	return nil;
}

- (COCommitTrack *)makeBranchWithLabel: (NSString *)aLabel atRevision: (CORevision *)aRev
{
	return nil;
}

- (COCommitTrack *)makeCopyFromRevision: (CORevision *)aRev
{
	return nil;
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
	return [storeUUIDString isEqual: [[[[self editingContext] store] UUID] stringValue]];
}

/* This method is called back through distributed notifications in various cases:
   - a commit calling -addRevision:toTrackUUID:
   - a selective undo or redo (this is the same than the previous case since 
     this results in a new commit)
   - an undo or redo calling -undoOnCommitTrack:
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

	COEditingContext *context = [[self editingContext] parentContext];
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

	// TODO: Remove the two lines below to be handled by the caching code 
	[[self cachedNodes] removeAllObjects];
	currentNodeIndex = NSNotFound;
	[self cacheNodesForward: CACHE_AMOUNT backward: CACHE_AMOUNT];

	// FIXME: The currentNodeIndex assertion requires that distributed 
	// notifications to be delivered (but the notification center might drop 
	// some notifications under heavy load according to Cocoa API doc)
	assert([[self currentNode] isEqual: oldCurrentNode] == NO);
	assert([self currentNode] != nil);
	assert(revNumber == [[[self currentNode] revision] revisionNumber]);

	/* For a commit in the receiver editing context, no reloading occurs 
	   because the tracked object state matches the revision */
	[[self editingContext] reloadAtRevision: [[self currentNode] revision]];

	[self didUpdate];
	RELEASE(oldCurrentNode);
}

- (void)setCurrentNode: (COTrackNode *)aNode
{
	INVALIDARG_EXCEPTION_TEST(aNode, [aNode track] == self);

	NSUInteger nodeIndex = [[self cachedNodes] indexOfObject: aNode];

	if (nodeIndex == NSNotFound)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Cannot find %@ on %@ currently", aNode, self];
	}
	currentNodeIndex = nodeIndex;

	assert([[self currentNode] isEqual: aNode]);

	[[[self editingContext] store] setCurrentRevision: [aNode revision]
	                                     forTrackUUID: [self UUID]];
	[[self editingContext] reloadAtRevision: [aNode revision]];
	[self didUpdate];
}

- (void)undo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot undo object %@ which does not have any commits", [self trackedObject]];
	}
	/* If -canUndo returns YES, before returning it loads some previous nodes 
	   to ensure currentNodeIndex is not zero and can be decremented */
	if ([self canUndo] == NO)
	{
		return;
	}

	/* We must update the current node before calling -undoOnCommitTrack: because
	   this last method posts a distributed notification that might be delivered 
	   before returning (at least on GNUstep, but not Mac OS X where immediate 
	   delivery behavior differs slightly). */
	currentNodeIndex--;
	// Check to make sure new node was cached
	NSAssert(currentNodeIndex != NSNotFound 
		&& ![[NSNull null] isEqual: [[self cachedNodes] objectAtIndex: currentNodeIndex]],
		@"Record undone to is cached");

	CORevision *currentRevision = [[[self editingContext] store] undoOnCommitTrack: [self UUID]];

	// TODO: Reset object state to old object.
	[[self editingContext] reloadAtRevision: currentRevision];

	[self didUpdate];
}

- (void)redo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot redo object %@ which does not have any commits", [self trackedObject]];
	}
	/* If -canRedo returns YES, before returning it loads some next nodes 
	   to ensure currentNodeIndex is not zero and can be incremented */
	if ([self canRedo] == NO)
	{
		return;
	}

	/* We must update the current node before calling -redoOnCommitTrack: because
	   this last method posts a distributed notification that might be delivered 
	   before returning (at least on GNUstep, but not Mac OS X where immediate 
	   delivery behavior differs slightly). */
	currentNodeIndex++;
	// Check to make sure new node was cached
	NSAssert([[self cachedNodes] count] > currentNodeIndex 
		&& ![[NSNull null] isEqual: [[self cachedNodes] objectAtIndex: currentNodeIndex]],
		@"Record redone to is cached");

	CORevision *currentRevision = [[[self editingContext] store] redoOnCommitTrack: [self UUID]];

	// TODO: Reset object state to old object.
	[[self editingContext] reloadAtRevision: currentRevision];

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
		               inEditingContext: [[self editingContext] parentContext]];
	}
}

- (COTrackNode *)nextNodeOnTrackFrom: (COTrackNode *)aNode backwards: (BOOL)back
{
	/* -cacheNodesForward:backward: can release this cached node */
	[aNode retain];
	NSArray *cachedNodes = [self cachedNodes];
	NSInteger nodeIndex = [cachedNodes indexOfObject: aNode];

	if (nodeIndex == NSNotFound)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Node %@ must belong to the track %@ to retrieve the previous or next node", aNode, self];
	}
	if (back)
	{
		nodeIndex--;
	}
	else
	{
		nodeIndex++;
	}

	/* Recache or return a cached node */

	if (nodeIndex < 0)
	{
		[self cacheNodesForward: 0 backward: currentNodeIndex + CACHE_AMOUNT];
	}
	else if (nodeIndex >= [cachedNodes count])
	{
		[self cacheNodesForward: nodeIndex - currentNodeIndex + CACHE_AMOUNT backward: 0];
	}
	else
	{
		return [cachedNodes objectAtIndex: nodeIndex];
	}

	/* Get the node from the updated cache */

	nodeIndex = [cachedNodes indexOfObject: aNode];
	[aNode release];

	if (back)
	{
		nodeIndex--;
	}
	else
	{
		nodeIndex++;
	}

	BOOL hasNoPreviousOrNextNode = (nodeIndex < 0 || nodeIndex >= [cachedNodes count]);

	if (hasNoPreviousOrNextNode)
	{
		return nil;
	}
	return [cachedNodes objectAtIndex: nodeIndex];
}

- (void)didMakeNewCommitAtRevision: (CORevision *)revision
{
	NSParameterAssert(revision != nil);

	COTrackNode *newNode = [COTrackNode nodeWithRevision: revision onTrack: self];
	/* At this point, revision is the max revision for the commit track */
	BOOL isTipNodeCached = [[[[self cachedNodes] lastObject] revision] isEqual: [revision baseRevision]];

	if (isTipNodeCached == NO)
	{
		[self cacheNodesForward: 0 backward: CACHE_AMOUNT];
	}
	[[self cachedNodes] addObject: newNode];

	if ([[self cachedNodes] count] > CACHE_AMOUNT)
	{
		[[self cachedNodes] removeObjectAtIndex: 0];
	}

	currentNodeIndex = [[self cachedNodes] count] - 1;

	[self didUpdate];
}

- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward
{
	COStore *store = [[self editingContext] store];
	NSUInteger newCurrentNodeIndex = 0;
	NSArray *revisions = [store revisionsForTrackUUID: [self UUID]
	                                 currentNodeIndex: &newCurrentNodeIndex
	                                    backwardLimit: backward
	                                     forwardLimit: forward];
	NSArray *backwardRange = [revisions subarrayWithRange: NSMakeRange(0, backward)];
	NSArray *forwardRange = [revisions subarrayWithRange: NSMakeRange(backward + 1, forward)];
	NSMutableArray *cachedNodes = [self cachedNodes];
	NSUInteger insertPoint;

	/* Recache before the current node */

	if (currentNodeIndex == NSNotFound)
	{
		insertPoint = 0;
		currentNodeIndex = 0;
	}
	else
	{
		insertPoint = currentNodeIndex;
	}

	for (CORevision *revision in [backwardRange reverseObjectEnumerator])
	{
		if ([[NSNull null] isEqual: revision])
			break;

		COTrackNode *node = [COTrackNode nodeWithRevision: revision onTrack: self];

		if (insertPoint == 0)
		{
			[cachedNodes insertObject: node atIndex: 0];
			currentNodeIndex++;
		}
		else
		{
			[cachedNodes replaceObjectAtIndex: insertPoint withObject: node];
			insertPoint--;
		}
	}

	/* Check the current node revision exists */

	CORevision *currentNodeRevision = [revisions objectAtIndex: backward];

	if ([[NSNull null] isEqual: currentNodeRevision])
	{
		currentNodeIndex = NSNotFound;
		return;
	}

	/* Recache the current node */

	COTrackNode *currentNode = [COTrackNode nodeWithRevision: [revisions objectAtIndex: backward]
	                                                 onTrack: self];

	if (currentNodeIndex >= [cachedNodes count])
	{
		[cachedNodes addObject: currentNode];
	}
	else
	{
		[cachedNodes replaceObjectAtIndex: currentNodeIndex withObject: currentNode];
	}

	/* Recache after the current node */

	insertPoint = currentNodeIndex + 1;

	for (CORevision *revision in forwardRange)
	{
		if ([[NSNull null] isEqual: revision])
			break;

		COTrackNode *node = [COTrackNode nodeWithRevision: revision onTrack: self];

		if (insertPoint >= [cachedNodes count])
		{
			[cachedNodes addObject: node];
		}
		else
		{
			[cachedNodes replaceObjectAtIndex: insertPoint withObject: node];
		}
		insertPoint++;
	}
}



@end
