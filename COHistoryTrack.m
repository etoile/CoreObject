#import "COHistoryTrack.h"


@implementation COHistoryTrack

/**
 * COHistoryTrack gives lets you make manipulations to the state of the store
 * like doing an undo with respect to a particular group of objects. It delegates
 * the actual changes to an editing context, where they must be committed.
 */
- (id)initTrackWithObject: (COObject*)container containedObjects: (BOOL)contained
{
	self = [super init];
	ASSIGN(obj, container);
	affectsContainedObjects = contained;
	return self;
}

- (void)dealloc
{
	DESTROY(obj);
	[super dealloc];
}

- (COHistoryTrackNode*)currentNode
{
	return nil;
}


/**
 * Convience method moves the current node one node closer to the tip, on
 * the path defined by starting at the tipNode and following parent pointers.
 */
- (COHistoryTrackNode*)redo
{
	return nil; // FIXME: non-primitive (implementable on the rest of the api)
}

- (NSSet*)currentObjectSet
{
	NSMutableSet *currentSet = [NSMutableSet set];
	[currentSet addObjectsFromArray: [obj allStronglyContainedObjects]];
	[currentSet addObject: obj];
	return currentSet;
}

- (CORevision*)currentParent
{
	NSSet *objSet = [self currentObjectSet];
	COEditingContext *ctx = [obj editingContext];
	COStore *store = [ctx store];
	
	// Fact the parent commit must be the parent commit of one of the objects
	// on objSet.
	NSMutableArray *potentialParents = [NSMutableArray array];
	for (COObject *o in objSet)
	{
		CORevision *commit = [store commitForUUID: [ctx currentCommitForObjectUUID: [o UUID]]];
		if (commit == nil)
		{
			// FIXME: what to do here?
			NSLog(@"WARNING, -[COHistoryTrack currentParent], current commit for object %@ is nil", [o UUID]);
		}
		else
		{
			CORevision *parentForObject = [commit parentCommitForObject: [o UUID]];
			[potentialParents addObject: parentForObject];
		}
	}
	
	// FIXME: As an optimisation, we just need to find the minimum element, not sort the whole array 
	[potentialParents sortUsingDescriptors: [NSArray arrayWithObject: [NSSortDescriptor sortDescriptorWithKey:@"metadata.date" ascending:NO]]];
	
	CORevision *parent = [potentialParents firstObject];
	return parent;
}

- (COHistoryTrackNode*)undo
{
#if 0
	COEditingContext *ctx = [obj editingContext];
	CORevision *parent = [self currentParent];
	//assert(parent != nil);
	
	NSMutableSet *objectsToUndo = [NSMutableSet set];
	[objectsToUndo addObjectsFromArray: [parent changedObjects]];
	[objectsToUndo intersectSet: [[[self currentObjectSet] mappedCollection] UUID]];
	
	
	// FIXME: We need to run the relationship integrity code _after_ the loop
	for (ETUUID *objectToUndo in objectsToUndo)
	{
		[ctx setCurrentCommit:parent forObjectUUID:objectToUndo];
	}
#endif
	return nil; // FIXME
}


/**
 * This figures out what current nodes need to be moved on the object
 * history graph, and moves them in ctx
 */
- (void)setCurrentNode: (COHistoryTrackNode*)node
{
}

/**
 * Moves the tip node
 */
- (void)setTipNode: (COHistoryTrackNode*)node
{
}


// FIXME: make this sketch work 
#if 0

// Sounds more tricky than currentParent
- (NSArray *)currentBranches
{
	NSSet *objSet = [self currentObjectSet];
	COEditingContext *ctx = [obj editingContext];
	
	NSMutableSet *potentialBranches = [NSMutableSet set];
	for (COObject *obj in objSet)
	{
		COCommit *commit = [ctx currentCommitForObjectUUID: [obj UUID]];
		[potentialParents addObjectsFromArray: [commit childCommitsForObject: [obj UUID]]];
	}

	// Note that we used a set to eliminate duplicates. Also note that the
	// return value is randomly ordered.
	return [potentialBranches allObjects];
}

#endif

/* Private */

- (NSArray*)changedObjectsForCommit: (CORevision*)commit
{
	
}
- (COHistoryTrackNode*)parentForCommit: (CORevision*)commit
{
	
}
- (COHistoryTrackNode*)mergedNodeForCommit: (CORevision*)commit
{
	
}
- (NSArray*)childNodesForCommit: (CORevision*)commit
{
	
}


@end



@implementation COHistoryTrackNode

- (NSDictionary*)metadata
{
	return [commit metadata];
}

- (NSArray*)changedObjects
{
	return [ownerTrack changedObjectsForCommit: commit];
}

/* History graph */

- (COHistoryTrackNode*)parent
{
	return [ownerTrack parentForCommit: commit];;
}

- (COHistoryTrackNode*)mergedNode
{
	return [ownerTrack mergedNodeForCommit: commit];
}

- (NSArray*)childNodes
{
	return [ownerTrack childNodesForCommit: commit];
}

/* Private */

- (CORevision*)underlyingCommit
{
	return commit;
}

@end