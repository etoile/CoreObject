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
	
	return self;
}


- (COHistoryTrackNode*)tipNode
{
	return nil;
}

- (COHistoryTrackNode*)currentNode
{
	return nil;
}


/**
 * Convience method moves the current node one node closer to the tip, on
 * the path defined by starting at the tipNode and following parent pointers.
 */
- (COHistoryTrackNode*)moveCurrentNodeForward
{
	return nil; // FIXME: non-primitive (implementable on the rest of the api)
}

/** 
 * Same as above, but moves one node away from the tip.
 */
- (COHistoryTrackNode*)moveCurrentNodeBackward
{
	return nil; // FIXME: non-primitive (implementable on the rest of the api)
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

/** This returns the UI's list of all branches for this history track
 * FIXME: maybe we should have open/closed as part of the api.
 */
- (NSArray*)namedBranches
{
	return nil;
}


- (CONamedBranch*)currentBranch
{
	return nil;
}

// FIXME: make this sketch work 
#if 0

- (NSSet*)currentObjectSet
{
	return [NSSet setWithArray: [obj allStronglyContainedObjects]];
}

- (COHistoryTrackNode*)currentParent
{
	NSSet *objSet = [self currentObjectSet];
	COEditingContext *ctx = [obj editingContext];
	
	// Fact the parent commit must be the parent commit of one of the objects
	// on objSet.
	NSMutableArray *potentialParents = [NSMutableArray array];
	for (COObject *obj in objSet)
	{
		COCommit *commit = [ctx currentCommitForObjectUUID: [obj UUID]];
		[potentialParents addObject: [commit parentCommitForObject: [obj UUID]]];
	}
	
	
	// FIXME: As an optimisation, we just need to find the minimum element, not sort the whole array 
	[potentialParents sortUsingDescriptors: [NSArray arrayWithObject: [NSSortDescriptor sortDescriptorWithKey:@"metadata.date" ascending:NO]]];
	
	COCommit *parent = [potentialParents firstObject];
}

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

/**
 * Changes the branch. Note that this effectively rebuilds the history track,
 * so tip node and current node will be different.
 *
 * Something to be careful of: suppose the branch we change to has more objects
 * in the docuemnt. It isn't sufficicent to simply find all strongly contained
 * objects of the document and change the branch on those.
 *
 * It has to be an interative process: change branch on the root object
 * then recursively change branch on each child.
 *
 * !!! We can introduce inconsistencies....
 *
 *
 */
- (void)setNamedBranch: (CONamedBranch*)branch
{
	[self setNamedBranch: branch recursivelyOnObject: obj];
}

- (void)setNamedBranch:(CONamedBranch *)branch recursivelyOnObject: (COObject*)anObject
{
	assert([anObject isKindOfClass: [COObject class]]);
	
	COEditingContext *ctx = [obj editingContext];

	// Ask the context to set the branch on this individual object. This should
	// reload all of its properties.

	[ctx setNamedBranch: [branch UUID] forObjectUUID: [anObject UUID]];
	 
	for (ETPropertyDescription *propDesc in [[anObject entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isComposite])
		{
			id value = [anObject valueForProperty: [propDesc name]];
			
			assert([propDesc isMultivalued] ==
				   ([value isKindOfClass: [NSArray class]] || [value isKindOfClass: [NSSet class]]));
			
			if ([propDesc isMultivalued])
			{
				for (id subvalue in value)
				{
					[self setNamedBranch: branch recursivelyOnObject: subvalue];
				}
			}
			else
			{
				[self setNamedBranch: branch recursivelyOnObject: value];
			}
		}
	}	
}

/* Private */

- (NSArray*)changedObjectsForCommit: (COCommit*)commit
{
	
}
- (COHistoryTrackNode*)parentForCommit: (COCommit*)commit
{
	
}
- (COHistoryTrackNode*)mergedNodeForCommit: (COCommit*)commit
{
	
}
- (NSArray*)childNodesForCommit: (COCommit*)commit
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

- (COCommit*)underlyingCommit
{
	return commit;
}

@end