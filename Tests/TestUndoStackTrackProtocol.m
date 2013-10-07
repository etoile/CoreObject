#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"
#import "CORevisionCache.h"

@interface TestUndoStackTrackProtocol : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
	COUndoTrack *track;
	
	CORevision *r0; // not on stack
	CORevision *r1;
	CORevision *r2;
	CORevision *r3;
	CORevision *r4;
}
@end

@implementation TestUndoStackTrackProtocol

- (id) init
{
    SUPERINIT;
	track = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
	[track clear];
	
    persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	[[persistentRoot rootObject] setLabel: @"0"];
	[ctx commit]; // not on stack
	r0 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"1"];
	[ctx commitWithUndoTrack: track];
	r1 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"2"];
	[ctx commitWithUndoTrack: track];
	r2 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"3"];
	[ctx commitWithUndoTrack: track];
	r3 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"4"];
	[ctx commitWithUndoTrack: track];
	r4 = [persistentRoot revision];
	
    return self;
}

- (void) checkCommand: (id<COTrackNode>)aCommand
	 isSetVersionFrom: (CORevision *)a
				   to: (CORevision *)b
{
	COCommandSetCurrentVersionForBranch *command = (COCommandSetCurrentVersionForBranch *)aCommand;
	UKObjectKindOf(command, COCommandSetCurrentVersionForBranch);
	UKObjectsEqual(a, command.oldRevision);
	UKObjectsEqual(b, command.revision);
}

- (void) testCurrentNodeAfter2Undo
{
	// The current node represents the change that was applied
	// to arrive the current state.
	//
	// Performing an undo would undo
	// the change represented by the current node.
	//
	// Performing a redo would apply the change after cuurentNode
	
	id <COTrackNode> current = [track currentNode];
	[self checkCommand: current isSetVersionFrom: r3 to: r4];
	
	// Now perform an undo with the COUndoStack API
	
	[track undo];
	current = [track currentNode];
	[self checkCommand: current isSetVersionFrom: r2 to: r3];
	
	// Perform another few undos
	
	[track undo];
	current = [track currentNode];
	[self checkCommand: current isSetVersionFrom: r1 to: r2];

	[track undo];
	current = [track currentNode];
	[self checkCommand: current isSetVersionFrom: r0 to: r1];
	
	[track undo];
	current = [track currentNode];
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], current);
}

- (void) testPreviousAndNextNodeWithUndo
{
	id <COTrackNode> current = [track currentNode];
	
	[self checkCommand: current isSetVersionFrom: r3 to: r4];
	
	[self checkCommand: [track nextNodeOnTrackFrom: current backwards: YES]
	  isSetVersionFrom: r2
					to: r3];
	
	UKNil([track nextNodeOnTrackFrom: current backwards: NO]);
	
	// Perform an undo
	
	[track undo];
	current = [track currentNode];
		
	[self checkCommand: current isSetVersionFrom: r2 to: r3];
	
	[self checkCommand: [track nextNodeOnTrackFrom: current backwards: YES]
	  isSetVersionFrom: r1
					to: r2];
	
	[self checkCommand: [track nextNodeOnTrackFrom: current backwards: NO]
	  isSetVersionFrom: r3
					to: r4];

	// Perform another undo

	[track undo];
	current = [track currentNode];
	
	[self checkCommand: current isSetVersionFrom: r1 to: r2];
	
	[self checkCommand: [track nextNodeOnTrackFrom: current backwards: YES]
	  isSetVersionFrom: r0
					to: r1];
	
	[self checkCommand: [track nextNodeOnTrackFrom: current backwards: NO]
	  isSetVersionFrom: r2
					to: r3];

}

- (void) testNextNodeOnTrackFromPlaceholder
{
	[track undo];
	[track undo];
	[track undo];
	[track undo];

	id <COTrackNode> current = [track currentNode];
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], current);
	
	current = [track nextNodeOnTrackFrom: current backwards: NO];
	[self checkCommand: current isSetVersionFrom: r0 to: r1];
}

- (void) checkNodes: (NSArray *)nodes
{
	// FIXME: This will need to be adjusted if we add the placeholder start
	// node as discussed above
	
	UKIntsEqual(5, [nodes count]);
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], nodes[0]);
	[self checkCommand: nodes[1] isSetVersionFrom: r0 to: r1];
	[self checkCommand: nodes[2] isSetVersionFrom: r1 to: r2];
	[self checkCommand: nodes[3] isSetVersionFrom: r2 to: r3];
	[self checkCommand: nodes[4] isSetVersionFrom: r3 to: r4];
}

- (void) testNodes
{
	NSArray *nodes = [track nodes];
	[self checkNodes: nodes];
}

// N.B.: These must be 3 separate tests, since [stack nodes] caches
// the result, and we need to make sure it's calculated corrently when there
// are are multiple commands in both the undo and redo stacks.

- (void) testNodesUnaffectedBy1Undo
{
	[track undo];
	[self checkNodes: [track nodes]];
}

- (void) testNodesUnaffectedBy2Undos
{
	[track undo];
	[track undo];
	[self checkNodes: [track nodes]];
}

- (void) testNodesUnaffectedBy3Undos
{
	[track undo];
	[track undo];
	[track undo];
	[self checkNodes: [track nodes]];
}

- (void) testNodesUnaffectedBy4Undos
{
	[track undo];
	[track undo];
	[track undo];
	[track undo];
	[self checkNodes: [track nodes]];
}

- (void) testSetCurrentNode
{
	id <COTrackNode> startNode = [track currentNode];
	id <COTrackNode> target = [track currentNode];
	target = [track nextNodeOnTrackFrom: target backwards: YES];
	target = [track nextNodeOnTrackFrom: target backwards: YES];
	
	[self checkCommand: target isSetVersionFrom: r1 to: r2];
	
	// Undo back 2 nodes
	
	[track setCurrentNode: target];
	
	[self checkCommand: [track currentNode] isSetVersionFrom: r1 to: r2];
	UKObjectsEqual(r2, [persistentRoot revision]);
	
	// Redo back to the start
	
	[track setCurrentNode: startNode];

	[self checkCommand: [track currentNode] isSetVersionFrom: r3 to: r4];
	UKObjectsEqual(r4, [persistentRoot revision]);
}

- (void) testSetCurrentNodeToPlaceholder
{
	id <COTrackNode> target = [track currentNode];
	target = [track nextNodeOnTrackFrom: target backwards: YES];
	target = [track nextNodeOnTrackFrom: target backwards: YES];
	target = [track nextNodeOnTrackFrom: target backwards: YES];
	target = [track nextNodeOnTrackFrom: target backwards: YES];
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], target);
	
	// Undo back 4 nodes
	
	[track setCurrentNode: target];

	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [track currentNode]);
	UKFalse([track canUndo]);
	UKTrue([track canRedo]);
	UKObjectsEqual(@"0", [[persistentRoot rootObject] label]);
	UKObjectsEqual(r0, [persistentRoot revision]);
	
	// Redo 1 node
	
	target = [track nextNodeOnTrackFrom: target backwards: NO];
	[track setCurrentNode: target];
	
	[self checkCommand: [track currentNode] isSetVersionFrom: r0 to: r1];
	UKTrue([track canUndo]);
	UKTrue([track canRedo]);
	UKObjectsEqual(@"1", [[persistentRoot rootObject] label]);
	UKObjectsEqual(r1, [persistentRoot revision]);
}

@end