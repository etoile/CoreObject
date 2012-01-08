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

#define CACHE_AMOUNT 5

@implementation COCommitTrack

@synthesize trackedObject;

- (id)initWithTrackedObjects: (NSSet *)trackedObjects
{
	INVALIDARG_EXCEPTION_TEST([trackedObjects count] > 1, @"A commit track can only track a single object at a time");

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

	return self;	
}

- (void)dealloc
{
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

- (void)undo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot undo object %@ which does not have any commits", trackedObject];
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
}
- (void)redo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot redo object %@ which does not have any commits", trackedObject];
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
}

- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward
{
	COStore *store = [[trackedObject editingContext] store];
	NSArray *revisions = [store loadCommitTrackForObject: [trackedObject UUID]
	                                        fromRevision: [[self currentNode] revision] 
	                                        nodesForward: forward
	                                       nodesBackward: backward];
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
