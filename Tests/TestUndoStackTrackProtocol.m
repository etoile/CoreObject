#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"
#import "CORevisionCache.h"

@interface TestUndoStackTrackProtocol : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
	COUndoTrack *stack;
	
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
	stack = [[COUndoStackStore defaultStore] stackForName: @"test"];
	[stack setEditingContext: ctx];
	[stack clear];
	
    persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	[[persistentRoot rootObject] setLabel: @"0"];
	[ctx commit]; // not on stack
	r0 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"1"];
	[ctx commitWithUndoStack: stack];
	r1 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"2"];
	[ctx commitWithUndoStack: stack];
	r2 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"3"];
	[ctx commitWithUndoStack: stack];
	r3 = [persistentRoot revision];
	
	[[persistentRoot rootObject] setLabel: @"4"];
	[ctx commitWithUndoStack: stack];
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
	
	id <COTrackNode> current = [stack currentNode];
	[self checkCommand: current isSetVersionFrom: r3 to: r4];
	
	// Now perform an undo with the COUndoStack API
	
	[stack undo];
	current = [stack currentNode];
	[self checkCommand: current isSetVersionFrom: r2 to: r3];
	
	// Perform another few undos
	
	[stack undo];
	current = [stack currentNode];
	[self checkCommand: current isSetVersionFrom: r1 to: r2];

	[stack undo];
	current = [stack currentNode];
	[self checkCommand: current isSetVersionFrom: r0 to: r1];
	
	[stack undo];
	current = [stack currentNode];
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], current);
}

- (void) testPreviousAndNextNodeWithUndo
{
	id <COTrackNode> current = [stack currentNode];
	
	[self checkCommand: current isSetVersionFrom: r3 to: r4];
	
	[self checkCommand: [stack nextNodeOnTrackFrom: current backwards: YES]
	  isSetVersionFrom: r2
					to: r3];
	
	UKNil([stack nextNodeOnTrackFrom: current backwards: NO]);
	
	// Perform an undo
	
	[stack undo];
	current = [stack currentNode];
		
	[self checkCommand: current isSetVersionFrom: r2 to: r3];
	
	[self checkCommand: [stack nextNodeOnTrackFrom: current backwards: YES]
	  isSetVersionFrom: r1
					to: r2];
	
	[self checkCommand: [stack nextNodeOnTrackFrom: current backwards: NO]
	  isSetVersionFrom: r3
					to: r4];

	// Perform another undo

	[stack undo];
	current = [stack currentNode];
	
	[self checkCommand: current isSetVersionFrom: r1 to: r2];
	
	[self checkCommand: [stack nextNodeOnTrackFrom: current backwards: YES]
	  isSetVersionFrom: r0
					to: r1];
	
	[self checkCommand: [stack nextNodeOnTrackFrom: current backwards: NO]
	  isSetVersionFrom: r2
					to: r3];

}

- (void) testNextNodeOnTrackFromPlaceholder
{
	[stack undo];
	[stack undo];
	[stack undo];
	[stack undo];

	id <COTrackNode> current = [stack currentNode];
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], current);
	
	current = [stack nextNodeOnTrackFrom: current backwards: NO];
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
	NSArray *nodes = [stack nodes];
	[self checkNodes: nodes];
}

// N.B.: These must be 3 separate tests, since [stack nodes] caches
// the result, and we need to make sure it's calculated corrently when there
// are are multiple commands in both the undo and redo stacks.

- (void) testNodesUnaffectedBy1Undo
{
	[stack undo];
	[self checkNodes: [stack nodes]];
}

- (void) testNodesUnaffectedBy2Undos
{
	[stack undo];
	[stack undo];
	[self checkNodes: [stack nodes]];
}

- (void) testNodesUnaffectedBy3Undos
{
	[stack undo];
	[stack undo];
	[stack undo];
	[self checkNodes: [stack nodes]];
}

- (void) testNodesUnaffectedBy4Undos
{
	[stack undo];
	[stack undo];
	[stack undo];
	[stack undo];
	[self checkNodes: [stack nodes]];
}

- (void) testSetCurrentNode
{
	id <COTrackNode> startNode = [stack currentNode];
	id <COTrackNode> target = [stack currentNode];
	target = [stack nextNodeOnTrackFrom: target backwards: YES];
	target = [stack nextNodeOnTrackFrom: target backwards: YES];
	
	[self checkCommand: target isSetVersionFrom: r1 to: r2];
	
	// Undo back 2 nodes
	
	stack.editingContext = ctx;
	[stack setCurrentNode: target];
	
	[self checkCommand: [stack currentNode] isSetVersionFrom: r1 to: r2];
	UKObjectsEqual(r2, [persistentRoot revision]);
	
	// Redo back to the start
	
	[stack setCurrentNode: startNode];

	[self checkCommand: [stack currentNode] isSetVersionFrom: r3 to: r4];
	UKObjectsEqual(r4, [persistentRoot revision]);
}

- (void) testSetCurrentNodeToPlaceholder
{
	id <COTrackNode> target = [stack currentNode];
	target = [stack nextNodeOnTrackFrom: target backwards: YES];
	target = [stack nextNodeOnTrackFrom: target backwards: YES];
	target = [stack nextNodeOnTrackFrom: target backwards: YES];
	target = [stack nextNodeOnTrackFrom: target backwards: YES];
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], target);
	
	// Undo back 4 nodes
	
	stack.editingContext = ctx;
	[stack setCurrentNode: target];

	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], [stack currentNode]);
	UKFalse([stack canUndo]);
	UKTrue([stack canRedo]);
	UKObjectsEqual(@"0", [[persistentRoot rootObject] label]);
	UKObjectsEqual(r0, [persistentRoot revision]);
	
	// Redo 1 node
	
	target = [stack nextNodeOnTrackFrom: target backwards: NO];
	[stack setCurrentNode: target];
	
	[self checkCommand: [stack currentNode] isSetVersionFrom: r0 to: r1];
	UKTrue([stack canUndo]);
	UKTrue([stack canRedo]);
	UKObjectsEqual(@"1", [[persistentRoot rootObject] label]);
	UKObjectsEqual(r1, [persistentRoot revision]);
}

@end