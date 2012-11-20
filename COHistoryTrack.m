/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import "COHistoryTrack.h"
#import "CORevision.h"
#import "COEditingContext.h"
#import "COPersistentRootEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COObjectGraphDiff.h"
#import "COStore.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COHistoryTrack

@synthesize includesInnerObjects;

- (id)initWithTrackedObjects: (NSSet *)objects
{
	SUPERINIT;
	ASSIGNCOPY(trackedObjects, objects);
	// TODO: Remove
	ASSIGN(trackObject, [trackedObjects anyObject]);
	includesInnerObjects = YES;
	return self;
}

- (void)dealloc
{
	DESTROY(trackedObjects);
	[super dealloc];
}

- (NSSet *)trackedObjects
{
	return trackedObjects;
}

- (COStore *)store
{
	return [[trackObject editingContext] store];
}

- (void)undo
{
	COTrackNode *currentNode = [self currentNode];
	
	if ([[currentNode metadata] valueForKey: @"undoMetadata"] != nil)
	{
		// we just undod
		int64_t lastUndo = [[[currentNode metadata] valueForKey: @"undoMetadata"] intValue];
		
		currentNode = [COTrackNode nodeWithRevision: [[self store] revisionWithRevisionNumber: lastUndo]
		                                           onTrack: self];
	}
	
	CORevision *revToUndo = [currentNode revision];
	CORevision *revBeforeUndo = [[currentNode previousNode] revision];
	
	COEditingContext *revToUndoCtx = [[COEditingContext alloc] initWithStore: [revToUndo store] maxRevisionNumber: [revToUndo revisionNumber]];
	COEditingContext *revBeforeUndoCtx = [[COEditingContext alloc] initWithStore: [revBeforeUndo store] maxRevisionNumber: [revBeforeUndo revisionNumber]];
	COEditingContext *currentRevisionCtx = [[trackObject editingContext] parentContext];
	
	COContainer *revToUndoObj = (COContainer*)[revToUndoCtx objectWithUUID: [trackObject UUID] atRevision: revToUndo];
	COContainer *revBeforeUndoObj = (COContainer*)[revBeforeUndoCtx objectWithUUID: [trackObject UUID] atRevision: revBeforeUndo];
	COContainer *currentRevisionObj = (COContainer*)[currentRevisionCtx objectWithUUID: [trackObject UUID]];
	
	COObjectGraphDiff *oa = [COObjectGraphDiff diffContainer: revToUndoObj withContainer: revBeforeUndoObj];
	COObjectGraphDiff *ob = [COObjectGraphDiff diffContainer: revToUndoObj withContainer: currentRevisionObj];	
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
	
	[merged applyToContext: revToUndoCtx];
	
	// Now we want to copy the changes from revToUnoCtx into our actual context
	
	COObjectGraphDiff *copier = [COObjectGraphDiff diffContainer: currentRevisionObj withContainer: revToUndoObj];
	[copier applyToContext: currentRevisionCtx];
	
	[currentRevisionCtx commitWithMetadata: [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: [revBeforeUndo revisionNumber]]
																		forKey: @"undoMetadata" ]];
	
//	[self setCurrentNode: [[self currentNode] previousNode]];
}

- (void)redo
{
	[self setCurrentNode: [[self currentNode] nextNode]];
}

- (BOOL)revisionIsOnTrack: (CORevision*)rev
{
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: [rev store]];
	COObject *objAtRev = [ctx objectWithUUID: [trackObject UUID] atRevision: rev];
	NSArray *allObjectsOnTrackAtRev = (NSArray*)[[[objAtRev allStronglyContainedObjectsIncludingSelf] mappedCollection] UUID];
	[ctx release];
	
	NSSet *allObjectsOnTrackAtRevSet = [NSSet setWithArray: allObjectsOnTrackAtRev];
	NSSet *changedSet = [NSSet setWithArray: [rev changedObjectUUIDs]];
	return [allObjectsOnTrackAtRevSet intersectsSet: changedSet];
}

- (CORevision *)nextRevisionOnTrackFrom: (CORevision *)rev backwards: (BOOL)back
{	
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: [rev store]];
	COObject *objAtRev = [ctx objectWithUUID: [trackObject UUID] atRevision: rev];
	NSArray *allObjectsOnTrackAtRev = (NSArray*)[[[objAtRev allStronglyContainedObjectsIncludingSelf] mappedCollection] UUID];
	[ctx release];
	objAtRev = nil;
	
	assert([allObjectsOnTrackAtRev count] > 0);

	NSSet *allObjectsOnTrackAtRevSet = [NSSet setWithArray: allObjectsOnTrackAtRev];
	CORevision *current = rev;
	while (1)
	{
		// Advance to the next number
		current = (back ? ([rev baseRevision]) : ([rev nextRevision]));
		
		if (nil == current)
		{
			return nil;
		}
		
		// Check if the current revison modified anything in allObjectsOnTrackAtRev
 		CORevision *newCurrentRev = current;
		assert(newCurrentRev != nil);
		NSSet *newCurrentRevModifiedSet = [NSSet setWithArray: [newCurrentRev changedObjectUUIDs]];
		
		if ([allObjectsOnTrackAtRevSet intersectsSet: newCurrentRevModifiedSet])
		{
			return newCurrentRev;
		}
	}
}


- (COTrackNode *)currentNode
{
	CORevision *rev = [trackObject revision];
	
	if (![self revisionIsOnTrack: rev])
	{
		rev = [self nextRevisionOnTrackFrom: rev backwards: YES];
	}
	
	return [COTrackNode nodeWithRevision: rev onTrack: self];	
}

- (void)setCurrentNode: (COTrackNode *)node
{

}

- (NSArray *) revisionsOnTrack
{
	ETAssert([trackObject isRoot]);

	COStore *store = [[trackObject editingContext] store];
	NSSet *rootAndInnerObjectUUIDs = [store UUIDsForRootObjectUUID: [trackObject UUID]];

	return [store revisionsForObjectUUIDs: rootAndInnerObjectUUIDs];
}

- (NSArray *)cachedNodes
{
	BOOL recache = (revNumberAtCacheTime != [[[trackObject editingContext] store] latestRevisionNumber]);

	if (recache)
	{
		// TODO: Recache only the new revisions if possible
		[[self cachedNodes] removeAllObjects];

		for (CORevision *rev in [self revisionsOnTrack])
		{
			[[self cachedNodes] addObject: [COTrackNode nodeWithRevision: rev onTrack: self]];
		}

		revNumberAtCacheTime = [[[trackObject editingContext] store] latestRevisionNumber];
	}
	return [self cachedNodes];
}

- (NSArray *)nodes
{
	return [self cachedNodes];
}

- (COTrackNode *)nextNodeOnTrackFrom: (COTrackNode *)aNode backwards: (BOOL)back
{
	// TODO: Implement
	return nil;
}

@end
