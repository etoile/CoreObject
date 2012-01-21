/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  January 2012
	License:  Modified BSD  (see COPYING)
 */

#import "COCustomTrack.h"
#import "COEditingContext.h"
#import "COObjectGraphDiff.h"
#import "CORevision.h"
#import "COStore.h"

@implementation COCustomTrack

@synthesize UUID, editingContext;

+ (id)trackWithUUID: (ETUUID *)aUUID editingContext: (COEditingContext *)aContext
{
	return AUTORELEASE([[self alloc] initWithUUID: aUUID editingContext: aContext]);
}

- (void) loadAllNodes
{
	BOOL wasPersisted = [[editingContext store] isTrackUUID: [self UUID]];

	if (wasPersisted == NO)
		return;

	NSArray *revisions = [[editingContext store] loadCommitTrackForObject: [self UUID]
	                                                         fromRevision: nil 
	                                                         nodesForward: NSUIntegerMax
	                                                        nodesBackward: NSUIntegerMax];
	NSMutableArray *cachedNodes = [self cachedNodes];

	[cachedNodes removeAllObjects];

	for (CORevision *rev in revisions)
	{
		[cachedNodes addObject: [COTrackNode nodeWithRevision: rev onTrack: self]];
	}
	currentNodeIndex = [cachedNodes count] - 1;
}

- (id)initWithUUID: (ETUUID *)aUUID editingContext: (COEditingContext *)aContext
{
	self = [super initWithTrackedObjects: [NSSet set]];
	if (self == nil)
		return nil;

	ASSIGN(UUID, aUUID);
	ASSIGN(editingContext, aContext);

	[self loadAllNodes];

	return self;
}

- (void)dealloc
{
	DESTROY(UUID);
	[super dealloc];
}

- (id)initWithTrackedObjects: (NSSet *)objects
{
	DESTROY(self);
	return nil;
}

- (void)addRevision: (CORevision *)rev
{
	[[self cachedNodes] addObject: [COTrackNode nodeWithRevision: rev onTrack: self]];

	currentNodeIndex = (currentNodeIndex == NSNotFound ? 0 : currentNodeIndex + 1);

	[[editingContext store] updateCommitTrackForRootObjectUUID: [[editingContext store] keyForUUID: [self UUID]]
	                                               newRevision: rev];
}

- (void)addRevisions: (NSArray *)revisions
{
	for (CORevision *rev in revisions)
	{
		[self addRevision: rev];
	}
	[self didUpdate];
}

- (COTrackNode *)nextNodeOnTrackFrom: (COTrackNode *)aNode backwards: (BOOL)back
{
	NSInteger nodeIndex = [[self cachedNodes] indexOfObject: aNode];

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

	BOOL hasNoPreviousOrNextNode = (nodeIndex < 0 || nodeIndex >= [[self cachedNodes] count]);

	if (hasNoPreviousOrNextNode)
	{
		return nil;
	}
	return [[self cachedNodes] objectAtIndex: nodeIndex];
}

- (void)undo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot undo when the track %@ is empty", self];
	}
	if ([[self currentNode] previousNode] == nil)
	{
		return;
	}

	CORevision *revToUndo = [[self currentNode] revision];
	COObject *object = [editingContext objectWithUUID: [revToUndo objectUUID]];

	assert([object isRoot]);
	assert([object isPersistent]);

	BOOL useCommitTrackUndo = [revToUndo isEqual: [editingContext revisionForObject: object]];
	
	if (useCommitTrackUndo)
	{
		CORevision *prevRev = [[editingContext store] maxRevision: [revToUndo revisionNumber] - 1 
		                                        forRootObjectUUID: [object UUID]];
		CORevision *newRev = nil;

		if (prevRev != nil)
		{
			newRev = [[editingContext store] undoOnCommitTrack: [object UUID]];
			[editingContext reloadRootObjectTree: object atRevision: newRev];
		}
		else
		{
			// TODO: Commit a delete

			/* Undo root object creation */
			[editingContext unloadRootObjectTree: object];
		}
	}
	else /* Fall back on selective undo */
	{
		CORevision *revBeforeUndo = [revToUndo baseRevision];
		COObjectGraphDiff *undoDiff = [COObjectGraphDiff selectiveUndoDiffWithRootObject: object 
	                                                                      revisionToUndo: revToUndo];

		[undoDiff applyToContext: editingContext];

		[editingContext commitWithMetadata: 
			D([NSNumber numberWithInt: [revBeforeUndo revisionNumber]], @"undoMetadata")];

		//[[editingContext store] updateCommitTrackForRootObjectUUID: [self UUID] 
		//                                               newRevision: [editingContext latestRevisionNumber]];
	}

	currentNodeIndex--;
	[self didUpdate];
}

- (void)redo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot redo when the track %@ is empty", self];
	}
	if ([[self currentNode] nextNode] == nil)
	{
		return;
	}

	CORevision *revToRedo = [[[self currentNode] nextNode] revision];
	COObject *object = [editingContext objectWithUUID: [revToRedo objectUUID]];

	assert([object isRoot]);
	assert([object isPersistent]);

	// NOTE: The base revision below is not the same than [currentNode revision] 
	// when the two revisions doesn't concern the same root object.
	BOOL useCommitTrackRedo = [[revToRedo baseRevision] isEqual: [editingContext revisionForObject: object]];
	
	if (useCommitTrackRedo)
	{
		CORevision *newRev = [[editingContext store] redoOnCommitTrack: [object UUID]];

	    [editingContext reloadRootObjectTree: object atRevision: newRev];
	}
	else /* Fall back on selective undo */
	{
		// TODO: Implement
	}

	currentNodeIndex++;
	[self didUpdate];
}

@end
