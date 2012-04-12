/*
	Copyright (C) 2011 Christopher Armstrong

	Author:  Christopher Armstrong <carmstrong@fastmail.com.au>
	Date:  September 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COCommitTrack.h"
#import "COEditingContext.h"
#import "COStore.h"
#import "COObject.h"
#import "CORevision.h"
#import "FMDatabase.h"

#define CACHE_AMOUNT 30

@implementation COCommitTrack

@synthesize trackedObject;

- (id)initWithTrackedObjects: (NSSet *)trackedObjects
{
	INVALIDARG_EXCEPTION_TEST(trackedObjects, [trackedObjects count] <= 1);

	COObject *object = [trackedObjects anyObject];

	if ([[object editingContext] store] == nil)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Cannot load commit track for object %@ which does not have a store or editing context", object];
	}

	self = [super initWithTrackedObjects: trackedObjects];
	if (self == nil)
		return nil;

	ASSIGN(trackedObject, object);
	if ([trackedObject revision] != nil)
	{
		[self cacheNodesForward: CACHE_AMOUNT backward: CACHE_AMOUNT];
	}

	[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
	                                                    selector: @selector(currentNodeDidChangeInStore:) 
	                                                        name: COStoreDidChangeCurrentNodeOnTrackNotification 
	                                                      object: [[trackedObject UUID] stringValue]];

	return self;	
}

- (void)dealloc
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
	DESTROY(trackedObject);
	[super dealloc];
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [COCommitTrack class]])
	{
		return ([trackedObject isEqual: [rhs trackedObject]]
			&& [[trackedObject editingContext] isEqual: [[rhs trackedObject] editingContext]]);
	}
	return NO;
}

- (void)checkCurrentNodeChangeNotification: (NSNotification *)notif
{
	NSString *storeUUIDString = [[notif userInfo] objectForKey: kCOStoreUUIDStringKey];

	assert([[notif object] isEqual: [[trackedObject UUID] stringValue]]);
	assert([storeUUIDString isEqual: [[[[trackedObject editingContext] store] UUID] stringValue]]);
}

- (void)currentNodeDidChangeInStore: (NSNotification *)notif
{

	[self checkCurrentNodeChangeNotification: notif];

	int64_t revNumber = [[[notif userInfo] objectForKey: kCONewCurrentNodeRevisionNumberKey] longLongValue];
	BOOL isOurTrack = (revNumber == [[[self currentNode] revision] revisionNumber]);

	/* We use notifications posted by tracked object tracks to be kept in sync 
	   with the store.
	   For concurrency control, we are not interested in notifications posted by 
	   our other instances (using our UUID) in some local or remote editing 
	   context. */
	if (isOurTrack)
		return;

	NSUInteger oldCurrentNodeIndex = currentNodeIndex;

	// TODO: Remove the two lines below to be handled by the caching code 
	[[self cachedNodes] removeAllObjects];
	currentNodeIndex = NSNotFound;
	[self cacheNodesForward: CACHE_AMOUNT backward: CACHE_AMOUNT];

	assert(currentNodeIndex != oldCurrentNodeIndex);
	assert([self currentNode] != nil);

	[[trackedObject editingContext] reloadRootObjectTree: trackedObject 
	                                          atRevision: [[self currentNode] revision]];

	[self didUpdate];
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

	[[[trackedObject editingContext] store] setCurrentRevision: [aNode revision]
	                                              forTrackUUID: [trackedObject UUID]];
	[[trackedObject editingContext] reloadRootObjectTree: trackedObject
	                                          atRevision: [aNode revision]];
	[self didUpdate];
}

- (void)undo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot undo object %@ which does not have any commits", trackedObject];
	}
	if ([self canUndo] == NO)
	{
		return;
	}

	COStore *store = [[trackedObject editingContext] store];
	CORevision *currentRevision = [store undoOnCommitTrack: [trackedObject UUID]];

	if (currentNodeIndex == 0)
	{
		[self cacheNodesForward: 0 backward: CACHE_AMOUNT];
	}
	currentNodeIndex--;
	// Check to make sure new node was cached
	NSAssert(currentNodeIndex != NSNotFound 
		&& ![[NSNull null] isEqual: [[self cachedNodes] objectAtIndex: currentNodeIndex]],
		@"Record undone to is cached");

	// TODO: Reset object state to old object.
	[[trackedObject editingContext] reloadRootObjectTree: trackedObject
	                                          atRevision: currentRevision];

	[self didUpdate];
}

- (void)redo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot redo object %@ which does not have any commits", trackedObject];
	}
	if ([self canRedo] == NO)
	{
		return;
	}

	COStore *store = [[trackedObject editingContext] store];
	CORevision *currentRevision = [store redoOnCommitTrack: [trackedObject UUID]];

	if ([[self cachedNodes] count] == (currentNodeIndex + 1))
	{
		[self cacheNodesForward: CACHE_AMOUNT backward: 0];
	}
	currentNodeIndex++;
	// Check to make sure new node was cached
	NSAssert([[self cachedNodes] count] > currentNodeIndex 
		&& ![[NSNull null] isEqual: [[self cachedNodes] objectAtIndex: currentNodeIndex]],
		@"Record redone to is cached");

	// TODO: Reset object state to old object.
	[[trackedObject editingContext] reloadRootObjectTree: trackedObject
	                                          atRevision: currentRevision];

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
		               inEditingContext: [trackedObject editingContext]];
	}
}

- (COTrackNode *)nextNodeOnTrackFrom: (COTrackNode *)aNode backwards: (BOOL)back
{
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

// TODO: Could be renamed -didMakeNewCommitAtRevision: to be more idiomatic
- (void)newCommitAtRevision: (CORevision *)revision
{
	// COStore takes care of updating the database, so we just use this as a 
	// notification to update our cache.
	COTrackNode *newNode = [COTrackNode nodeWithRevision: revision onTrack: self];

	if (currentNodeIndex != NSNotFound)
	{
		currentNodeIndex++;
	}
	else
	{
		currentNodeIndex = 0;
	}
	[[self cachedNodes] insertObject: newNode atIndex: currentNodeIndex];

	NSUInteger lastIndex = [[self cachedNodes] count] - 1;
	BOOL evictsNodesFromCache = (lastIndex > currentNodeIndex);

	if (evictsNodesFromCache)
	{
		NSRange range = NSMakeRange(currentNodeIndex + 1, lastIndex - currentNodeIndex);
		[[self cachedNodes] removeObjectsInRange: range];
	}

	[self didUpdate];
}

- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward
{
	COStore *store = [[trackedObject editingContext] store];
	NSUInteger newCurrentNodeIndex = 0;
	NSArray *revisions = [store revisionsForTrackUUID: [trackedObject UUID]
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
