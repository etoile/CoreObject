#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"
#import "CORevisionCache.h"

@interface TestUndoStackTrackProtocol : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
	COUndoStack *stack;
	
	CORevision *r0; // not on stack
	CORevision *r1;
	CORevision *r2;
}
@end

@implementation TestUndoStackTrackProtocol

- (id) init
{
    SUPERINIT;
	stack = [[COUndoStackStore defaultStore] stackForName: @"test"];
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
	
    return self;
}

- (void) testCurrentNodeAfterUndo
{
	// The current node represents the change that was applied
	// to arrive the current state.
	//
	// Performing an undo would undo
	// the change represented by the current node.
	//
	// Performing a redo would apply the change after cuurentNode
	
	id <COTrackNode> current = [stack currentNode];
	
	{
		COCommandSetCurrentVersionForBranch *command = (COCommandSetCurrentVersionForBranch *)current;
		UKObjectKindOf(command, COCommandSetCurrentVersionForBranch);
		UKObjectsEqual(r1, command.oldRevision);
		UKObjectsEqual(r2, command.revision);
	}
	
	// Now perform an undo with the COUndoStack API
	
	[stack undoWithEditingContext: ctx];
	
	current = [stack currentNode];
	
	{
		COCommandSetCurrentVersionForBranch *command = (COCommandSetCurrentVersionForBranch *)current;
		UKObjectKindOf(command, COCommandSetCurrentVersionForBranch);
		UKObjectsEqual(r0, command.oldRevision);
		UKObjectsEqual(r1, command.revision);
	}
	
	// Perform another undo to bring us back to r0
	
	[stack undoWithEditingContext: ctx];
	
	current = [stack currentNode];
	UKNil(current);
}

@end