 /*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  January 2012
	License:  Modified BSD  (see COPYING)
 */

#import "COCustomTrack.h"
#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COObject.h"
#import "COObjectGraphDiff.h"
#import "CORevision.h"
#import "COStore.h"

@implementation COCustomTrack

@synthesize UUID, editingContext;

+ (id)trackWithUUID: (ETUUID *)aUUID editingContext: (COEditingContext *)aContext
{
	return AUTORELEASE([[self alloc] initWithUUID: aUUID editingContext: aContext]);
}

- (id)initWithUUID: (ETUUID *)aUUID editingContext: (COEditingContext *)aContext
{
	SUPERINIT;

	ASSIGN(UUID, aUUID);
	ASSIGN(editingContext, aContext);

	[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
	                                                    selector: @selector(currentNodeDidChangeInStore:) 
	                                                        name: COStoreDidChangeCurrentNodeOnTrackNotification 
	                                                      object: nil];

	return self;
}

- (void)dealloc
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
	DESTROY(UUID);
	DESTROY(editingContext);
	[super dealloc];
}

- (NSSet *)trackedObjectUUIDs
{
	// TODO: This is probably quite slow. We can query the store to compute the 
	// the tracked object set.
	NSArray *revs = (id)[[[self loadedNodes] mappedCollection] revision];
	// TODO: Should we skip UUIDs matching tracked objects which have been 
	// deleted at this point, see -trackedObjects and -currentNodeDidChangeInStore:...
	return [NSSet setWithArray: (id)[[revs mappedCollection] objectUUID]];
}

- (NSSet *)trackedObjects
{
	NSMutableSet *objects = [NSMutableSet set];

	// TODO: Skip tracked objects which have been deleted at this point, see 
	// -trackedObjectUUIDs
	for (ETUUID *uuid in [self trackedObjectUUIDs])
	{
		[objects addObject: [editingContext objectWithUUID: uuid]];
	}
	return objects;
}

- (NSArray *)allNodesAndCurrentNodeIndex: (NSUInteger *)aNodeIndex
{
	return [[editingContext store] nodesForTrackUUID: [self UUID]
	                                     nodeBuilder: self
	                                currentNodeIndex: aNodeIndex
	                                   backwardLimit: NSUIntegerMax
	                                    forwardLimit: NSUIntegerMax];
}

- (NSArray *)provideNodesAndCurrentNodeIndex:(NSUInteger *)aNodeIndex
{
	NSUInteger newNodeIndex = 0;
	NSArray *allNodes = [self allNodesAndCurrentNodeIndex: &newNodeIndex];
	NSMutableArray *nodes = [NSMutableArray array];
	COStore *store = [editingContext store];
	CORevision *currentRev = [store currentRevisionForTrackUUID: [self UUID]];
	
	
	for (COTrackNode *node in allNodes)
	{
		// TODO: If necessary, we can cache the current rev per object UUID and
		// retrieve all the commit track current revisions in a single SQL query.
		CORevision *commitTrackRev = [store currentRevisionForTrackUUID: [[node revision] objectUUID]];
		int64_t commitTrackRevNumber = [commitTrackRev revisionNumber];
		int64_t currentRevNumber = [currentRev revisionNumber];
		int64_t revNumber = [[node revision] revisionNumber];
		
		if ((revNumber > commitTrackRevNumber && revNumber < currentRevNumber)
			|| (revNumber > currentRevNumber && revNumber < commitTrackRevNumber))
		{
			newNodeIndex--;
			continue;
		}
		
		[nodes addObject: node];
	}
	
	*aNodeIndex = newNodeIndex;
	return nodes;
}

- (BOOL)isOurStoreForNotification: (NSNotification *)notif
{
	NSString *storeUUIDString = [[notif userInfo] objectForKey: kCOStoreUUIDStringKey];
	return [storeUUIDString isEqual: [[[[self editingContext] store] UUID] stringValue]];
}

- (void)currentNodeDidChangeInStore: (NSNotification *)notif
{
	ETUUID *trackUUID = [ETUUID UUIDWithString: [notif object]];
	BOOL isOurTrack = [[self UUID] isEqual: trackUUID];

	/* We use notifications posted by tracked object tracks to be kept in sync 
	   with the store.
	   For concurrency control, we are not interested in notifications posted by 
	   our other instances (using our UUID) in some local or remote editing 
	   context. */
	if (isOurTrack)
		return;

	/* Paranoid check in case something goes wrong and a core object UUID 
	   appear in multiple stores. 
	   For now, a core object UUID is bound to a single store. Hence a commit
	   track UUID is never in use accross multiple stores (using distinct UUIDs).  */
	if ([self isOurStoreForNotification: notif] == NO)
		return;

	BOOL isTrackedObjectTrack = [[self trackedObjectUUIDs] containsObject: trackUUID];

	if (isTrackedObjectTrack == NO)
		return;

	CORevision *oldRev = [[self currentNode] revision];
	int64_t newRevNumber = [[[notif userInfo] objectForKey: kCONewCurrentNodeRevisionNumberKey] longLongValue];

	if ([oldRev revisionNumber] == newRevNumber)
		return;

	// TODO: Reuse nodes (we reinstantiate every node currently)
	[self reloadNodes];

	CORevision *newRev = [[editingContext store] revisionWithRevisionNumber: newRevNumber];
	ETUUID *commitTrackUUID = [newRev objectUUID];
	COTrackNode *node = [self currentNode];

	if (newRevNumber < [oldRev revisionNumber])
	{
		while (node != nil)
		{
			if ([[node revision] isEqual: newRev] 
			 || [[[node revision] objectUUID] isEqual: commitTrackUUID] == NO)
			{
				break;
			}

			currentNodeIndex--;
			node = [node previousNode];
		}
	}
	else /* newRevNumber > [oldRev revisionNumber] */
	{
		while (node != nil)
		{
			if ([[node revision] isEqual: newRev]
			 || [[[[node nextNode] revision] objectUUID] isEqual: commitTrackUUID] == NO)
			{
				break;
			}

			currentNodeIndex++;
			node = [node nextNode];
		}	
	}
	// NOTE: At this point, [[[self currentNode] revision] isEqual: newRev] 
	// won't hold if the object UUID for the current custom track revision
	// doesn't match the newRev object UUID.
	[[editingContext store] setCurrentRevision: [[self currentNode] revision]
	                              forTrackUUID: [self UUID]];

	/* We don't have to reload the tracked object at the current track node 
	   revision, because its commit track does it. */

	[self didUpdate];
}

- (void)addRevision: (CORevision *)rev
{
	[[self loadedNodes] addObject: [COTrackNode nodeWithID: [rev commitNodeID]
	                                              revision: rev
	                                               onTrack: self]];

	currentNodeIndex = (currentNodeIndex == NSNotFound ? 0 : currentNodeIndex + 1);

	[[editingContext store] addRevision: rev toTrackUUID: [self UUID]];
}

- (void)addRevisions: (NSArray *)revisions
{
	for (CORevision *rev in revisions)
	{
		[self addRevision: rev];
	}
	[self didUpdate];
}

- (void)undo
{
	if ([self currentNode] == nil)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot undo when the track %@ is empty", self];
	}
	if ([self canUndo] == NO)
	{
		return;
	}

	CORevision *revToUndo = [[self currentNode] revision];
	COObject *object = [editingContext objectWithUUID: [revToUndo objectUUID]];

	assert([object isRoot]);
	assert([object isPersistent]);

	BOOL useCommitTrackUndo = [revToUndo isEqual: [object revision]];
	
	if (useCommitTrackUndo)
	{
		CORevision *prevRev = [[editingContext store] maxRevision: [revToUndo revisionNumber] - 1 
		                                       forCommitTrackUUID: [self UUID]];
		
		if (prevRev != nil)
		{
			//CORevision *newTrackRev = [[editingContext store] undoOnTrackUUID: [self UUID]];
			CORevision *newRev = [[editingContext store] undoOnTrackUUID: [object UUID]];

			//assert([newTrackRev isEqual: [[[self currentNode] previousNode] revision]]);

			[[object persistentRoot] reloadAtRevision: newRev];
		}
		else
		{
			// TODO: Commit a delete

			/* Undo root object creation */
			[[object persistentRoot] unload];
		}
	}
	else
	{
		[self selectiveUndoWithRevision: revToUndo inEditingContext: editingContext];
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
	if ([self canRedo] == NO)
	{
		return;
	}

	CORevision *revToRedo = [[[self currentNode] nextNode] revision];
	COObject *object = [editingContext objectWithUUID: [revToRedo objectUUID]];

	assert([object isRoot]);
	assert([object isPersistent]);

	// NOTE: The base revision below is not the same than [currentNode revision] 
	// when the two revisions doesn't concern the same root object.
	BOOL useCommitTrackRedo = [[revToRedo baseRevision] isEqual: [object revision]];
	
	if (useCommitTrackRedo)
	{
		//CORevision *newTrackRev = [[editingContext store] redoOnTrackUUID: [self UUID]];
		CORevision *newRev = [[editingContext store] redoOnTrackUUID: [object UUID]];

		//assert([newTrackRev isEqual: [[[self currentNode] nextNode] revision]]);

	    [[object persistentRoot] reloadAtRevision: newRev];
	}
	else /* Fall back on selective undo */
	{
		// TODO: Implement
	}

	currentNodeIndex++;
	[self didUpdate];
}

@end
