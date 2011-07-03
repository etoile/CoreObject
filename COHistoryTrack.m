#import "COHistoryTrack.h"
#import "CORevision.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COObjectGraphDiff.h"
#import "COStore.h"

@implementation COHistoryTrack

- (id)initTrackWithObject: (COObject*)container containedObjects: (BOOL)contained
{
	self = [super init];
	ASSIGN(trackObject, container);
	affectsContainedObjects = contained;
	return self;
}

- (void)dealloc
{
	DESTROY(trackObject);
	[super dealloc];
}

- (void)setCurrentNode: (COHistoryTrackNode*)node
{
}

- (COHistoryTrackNode*)currentNode
{
	CORevision *rev = [[self store] revisionWithRevisionNumber: [[self store] latestRevisionNumber]];
	
	if (![self revisionIsOnTrack: rev])
	{
		rev = [self nextRevisionOnTrackAfter: rev backwards: YES];
	}
	
	return [COHistoryTrackNode nodeWithRevision: rev
										  owner: self];	
}

- (COHistoryTrackNode*)undo
{
	COHistoryTrackNode *currentNode = [self currentNode];
	
	if ([[currentNode metadata] valueForKey: @"undoMetadata"] != nil)
	{
		// we just undod
		uint64_t lastUndo = [[[currentNode metadata] valueForKey: @"undoMetadata"] intValue];
		
		currentNode = [COHistoryTrackNode nodeWithRevision: [[self store] revisionWithRevisionNumber: lastUndo]
													 owner: self];
	}
	
	CORevision *revToUndo = [currentNode underlyingRevision];
	CORevision *revBeforeUndo = [[currentNode parent] underlyingRevision];
	
	COEditingContext *revToUndoCtx = [[COEditingContext alloc] initWithRevision: revToUndo];
	COEditingContext *revBeforeUndoCtx = [[COEditingContext alloc] initWithRevision: revBeforeUndo];
	COEditingContext *currentRevisionCtx = [trackObject editingContext];
	
	COContainer *revToUndoObj = (COContainer*)[revToUndoCtx objectWithUUID: [trackObject UUID]];
	COContainer *revBeforeUndoObj = (COContainer*)[revBeforeUndoCtx objectWithUUID: [trackObject UUID]];
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
	
//	[self setCurrentNode: [[self currentNode] parent]];
	return [self currentNode];
}

- (COHistoryTrackNode*)redo
{
	[self setCurrentNode: [[self currentNode] child]];
	return [self currentNode];
}


/* Private */

- (COStore*)store
{
	return [[trackObject editingContext] store];
}

- (BOOL)revisionIsOnTrack: (CORevision*)rev
{
	COEditingContext *ctx = [[COEditingContext alloc] initWithRevision: rev];
	COObject *objAtRev = [ctx objectWithUUID: [trackObject UUID]];
	NSArray *allObjectsOnTrackAtRev = (NSArray*)[[[objAtRev allStronglyContainedObjectsIncludingSelf] mappedCollection] UUID];
	[ctx release];
	
	NSSet *allObjectsOnTrackAtRevSet = [NSSet setWithArray: allObjectsOnTrackAtRev];
	NSSet *changedSet = [NSSet setWithArray: [rev changedObjects]];
	return [allObjectsOnTrackAtRevSet intersectsSet: changedSet];
}

- (CORevision *)nextRevisionOnTrackAfter: (CORevision *)rev backwards: (BOOL)back
{	
	COEditingContext *ctx = [[COEditingContext alloc] initWithRevision: rev];
	COObject *objAtRev = [ctx objectWithUUID: [trackObject UUID]];
	NSArray *allObjectsOnTrackAtRev = (NSArray*)[[[objAtRev allStronglyContainedObjectsIncludingSelf] mappedCollection] UUID];
	[ctx release];
	objAtRev = nil;
	
	assert([allObjectsOnTrackAtRev count] > 0);

	NSSet *allObjectsOnTrackAtRevSet = [NSSet setWithArray: allObjectsOnTrackAtRev];
	int64_t current = [rev revisionNumber];
	while (1)
	{
		// Advance to the next number
		current = (back ? (current - 1) : (current + 1));
		
		if (current < 1 || current > [[self store] latestRevisionNumber])
		{
			return nil;
		}
		
		// Check if the current revison modified anything in allObjectsOnTrackAtRev
 		CORevision *newCurrentRev = [[self store] revisionWithRevisionNumber: current];
		assert(newCurrentRev != nil);
		NSSet *newCurrentRevModifiedSet = [NSSet setWithArray: [newCurrentRev changedObjects]];
		
		if ([allObjectsOnTrackAtRevSet intersectsSet: newCurrentRevModifiedSet])
		{
			return newCurrentRev;
		}
	}
}


@end



@implementation COHistoryTrackNode

- (NSDictionary*)metadata
{
	return [revision metadata];
}

/* History graph */

- (COHistoryTrackNode*)parent
{
	CORevision *parentRev = [ownerTrack nextRevisionOnTrackAfter: revision backwards: YES];
	return [COHistoryTrackNode nodeWithRevision:parentRev owner: ownerTrack];
}

- (COHistoryTrackNode*)child
{
	return nil;
}
- (NSArray*)secondaryBranches
{
	return nil;
}

/* Private */

+ (COHistoryTrackNode*)nodeWithRevision: (CORevision*)aRevision owner: (COHistoryTrack*)anOwner
{
	COHistoryTrackNode *node = [[[self alloc] init] autorelease];
	node->revision = [aRevision retain];
	node->ownerTrack = anOwner;
	return node;
}

- (void)dealloc
{
	[revision release];
	[super dealloc];
}

- (CORevision*)underlyingRevision
{
	return revision;
}

@end
