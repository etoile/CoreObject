#import "COHistoryTrack.h"
#import "CORevision.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"
#import "COObjectGraphDiff.h"
#import "COStore.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COHistoryTrack

+ (void) initialize
{
	if (self != [COHistoryTrack class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

- (id)initTrackWithObject: (COObject*)container containedObjects: (BOOL)contained
{
	self = [super init];
	ASSIGN(trackObject, container);
	affectsContainedObjects = contained;
	cachedTrackNodes = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	DESTROY(trackObject);
	DESTROY(cachedTrackNodes);
	[super dealloc];
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

- (void)setCurrentNode: (COHistoryTrackNode*)node
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
		[cachedTrackNodes removeAllObjects];

		for (CORevision *rev in [self revisionsOnTrack])
		{
			[cachedTrackNodes addObject: [COHistoryTrackNode nodeWithRevision: rev owner: self]];
		}

		revNumberAtCacheTime = [[[trackObject editingContext] store] latestRevisionNumber];
	}
	return cachedTrackNodes;
}

- (NSArray *)nodes
{
	return [self cachedNodes];
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
	NSSet *changedSet = [NSSet setWithArray: [rev changedObjectUUIDs]];
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
		NSSet *newCurrentRevModifiedSet = [NSSet setWithArray: [newCurrentRev changedObjectUUIDs]];
		
		if ([allObjectsOnTrackAtRevSet intersectsSet: newCurrentRevModifiedSet])
		{
			return newCurrentRev;
		}
	}
}

/** Returns YES. */
- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return 	[self cachedNodes];
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: [self cachedNodes]];
}

@end



@implementation COHistoryTrackNode

- (NSDictionary *)metadata
{
	return [revision metadata];
}

- (uint64_t)revisionNumber
{
	return [revision revisionNumber];
}

- (ETUUID *)UUID
{
	return [revision UUID];
}

- (NSArray*)changedObjectUUIDs
{
	return [revision changedObjectUUIDs];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"revisionNumber", @"UUID", @"metadata", @"changedObjectUUIDs")];
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
