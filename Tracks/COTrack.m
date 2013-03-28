/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COTrack.h"
#import "COEditingContext.h"
#import "COObjectGraphDiff.h"
#import "CORevision.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COTrack

/* For debugging with Clang and GDB on GNUstep (ivar printing doesn't work) */
- (NSUInteger)currentNodeIndex
{
	return currentNodeIndex;
}

+ (void) initialize
{
	if (self != [COTrack class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

- (id)init
{
	SUPERINIT;
	loadedNodes =  [[NSMutableArray alloc] init]; 
	currentNodeIndex = NSNotFound;
	return self;	
}

- (NSSet *)trackedObjects
{
	return [NSSet set];
}

- (BOOL)needsReloadNodes: (NSArray *)currentLoadedNodes
{
	return [currentLoadedNodes isEmpty];
}

- (NSMutableArray *)loadedNodes
{
	if ([self needsReloadNodes: loadedNodes] && isLoading == NO)
	{
		isLoading = YES;
		[self reloadNodes];
		isLoading = NO;
	}
	return loadedNodes;
}

- (NSArray *)provideNodesAndCurrentNodeIndex: (NSUInteger *)aNodeIndex
{
	return [NSArray array];
}

- (void)reloadNodes
{
	[loadedNodes setArray: [self provideNodesAndCurrentNodeIndex: &currentNodeIndex]];
	[self didReloadNodes];
}

- (void)didReloadNodes
{
	
}

- (COTrackNode *)nextNodeOnTrackFrom: (COTrackNode *)aNode backwards: (BOOL)back
{
	NSInteger nodeIndex = [[self loadedNodes] indexOfObject: aNode];
	
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
	
	BOOL hasNoPreviousOrNextNode = (nodeIndex < 0 || nodeIndex >= [[self loadedNodes] count]);
	
	if (hasNoPreviousOrNextNode)
	{
		return nil;
	}
	return [[self loadedNodes] objectAtIndex: nodeIndex];
}

- (COTrackNode *)makeNodeWithID: (int64_t)aNodeID revision: (CORevision *)aRevision
{
	return [COTrackNode nodeWithID: aNodeID revision: aRevision onTrack: self];
}

- (COTrackNode *)currentNode
{
	/* Force node recache */
	NSArray *nodes = [self loadedNodes];

	return (currentNodeIndex != NSNotFound ? [nodes objectAtIndex: currentNodeIndex] : nil);
}

- (void)setCurrentNode: (COTrackNode *)node
{

}

- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (void)undo
{

}

- (void)redo
{

}

- (void)undoNode: (COTrackNode *)aNode
{

}

- (void)selectiveUndoWithRevision: (CORevision *)revToUndo 
                 inEditingContext: (COEditingContext *)ctxt
{
	NILARG_EXCEPTION_TEST(revToUndo);
	NILARG_EXCEPTION_TEST(ctxt);

	CORevision *revBeforeUndo = [revToUndo baseRevision];
	COObject *object = [ctxt objectWithUUID: [revToUndo objectUUID]];
	COObjectGraphDiff *undoDiff = [COObjectGraphDiff selectiveUndoDiffWithRootObject: object
																	  revisionToUndo: revToUndo];

	[undoDiff applyToContext: ctxt];

	/* The track nodes are going to be transparently updated, then 
	  -didUpdate invoked by -newCommitAtRevision:  */
	[ctxt commitWithMetadata: D([NSNumber numberWithInt: [revBeforeUndo revisionNumber]], @"undoMetadata")];
}

- (BOOL)canUndo
{
	return ([[self currentNode] previousNode] != nil);
}

- (BOOL)canRedo
{
	return ([[self currentNode] nextNode] != nil);
}

/** Returns YES. */
- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return 	[self loadedNodes];
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: [self loadedNodes]];
}

@end


@implementation COTrackNode

+ (id)nodeWithID: (int64_t)aNodeID revision: (CORevision *)aRevision onTrack: (COTrack *)aTrack;
{
	return AUTORELEASE([[self alloc] initWithID: aNodeID revision: aRevision onTrack: aTrack]);
}

+ (id)nodeWithRevision: (CORevision *)aRevision onTrack: (COTrack *)aTrack;
{
	return [self nodeWithRevision: aRevision onTrack: aTrack];
}

- (id)initWithID: (int64_t)aNodeID revision: (CORevision *)rev onTrack: (COTrack *)aTrack
{
	NILARG_EXCEPTION_TEST(rev);
	NILARG_EXCEPTION_TEST(aTrack);
	SUPERINIT;
	nodeID = aNodeID;
	ASSIGN(revision, rev);
	track = aTrack;
	return self;
}

- (void)dealloc
{
	[revision release];
	[super dealloc];
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [COTrackNode class]])
	{
		return ([revision isEqual: [rhs revision]] && [track isEqual: [rhs track]]);
	}
	return NO;
}

// NOTE: For Mac OS X at least, KVC doesn't check -forwardingTargetForSelector:, 
// so implementing it is pretty much useless. We had to reimplement the accessors (see below).
- (id)forwardingTargetForSelector: (SEL)aSelector
{
	if ([revision respondsToSelector: aSelector])
	{
		return revision;
	}
	return nil;
}

- (int64_t)nodeID
{
	return nodeID;
}

- (CORevision *)revision
{
	return revision;
}

- (COTrack *)track
{
	return track;
}

- (COTrackNode *)previousNode
{
	return [track nextNodeOnTrackFrom: self backwards: YES];
}

- (COTrackNode *)nextNode
{
	return [track nextNodeOnTrackFrom: self backwards: NO];
}

- (NSDictionary *)metadata
{
	return [revision metadata];
}

- (int64_t)revisionNumber
{
	return [revision revisionNumber];
}

- (ETUUID *)UUID
{
	return [revision UUID];
}

- (ETUUID *)persistentRootUUID
{
	return [revision persistentRootUUID];
}

- (ETUUID *)trackUUID
{
	return [revision trackUUID];
}

- (ETUUID *)objectUUID
{
	return [revision objectUUID];
}

- (NSDate *)date
{
	return [revision date];
}

- (NSString *)type
{
	return [revision type];
}

- (NSString *)shortDescription;
{
	return [revision shortDescription];
}

- (NSString *)longDescription
{
	return [revision longDescription];
}

- (NSArray *)changedObjectUUIDs
{
	return [revision changedObjectUUIDs];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: [revision propertyNames]];
}

@end
