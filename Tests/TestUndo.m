#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestUndo : EditingContextTestCase <UKTest>
{
    COUndoStack *_testStack;
    COUndoStack *_setupStack;
    COUndoStack *_rootEditStack;
    COUndoStack *_childEditStack;
}
@end

@implementation TestUndo

- (id) init
{
    SUPERINIT;
    
    _testStack =  [[COUndoStackStore defaultStore] stackForName: @"test"];
	[_testStack setEditingContext: ctx];
    _setupStack =  [[COUndoStackStore defaultStore] stackForName: @"setup"];
	[_setupStack setEditingContext: ctx];
    _rootEditStack =  [[COUndoStackStore defaultStore] stackForName: @"rootEdit"];
	[_rootEditStack setEditingContext: ctx];
    _childEditStack =  [[COUndoStackStore defaultStore] stackForName: @"childEdit"];
	[_childEditStack setEditingContext: ctx];
    
    [_testStack clear];
    [_setupStack clear];
    [_rootEditStack clear];
    [_childEditStack clear];
    
    return self;
}


- (void)testUndoSetCurrentVersionForBranchBasic
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoStack: _testStack];

    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithUndoStack: _testStack];
    
    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [_testStack undo];
    
    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
}

- (void)testUndoSetCurrentVersionForBranchMultiplePersistentRoots
{
    COPersistentRoot *persistentRoot1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoStack: _testStack];
    
    [[persistentRoot1 rootObject] setLabel: @"hello1"];
    [[persistentRoot2 rootObject] setLabel: @"hello2"];
    [ctx commitWithUndoStack: _testStack];
    
    CORevision *persistentRoot1Revision = [persistentRoot1 revision];
    CORevision *persistentRoot2Revision = [persistentRoot2 revision];
    
    [_testStack undo];
    
    UKObjectsNotEqual([persistentRoot1 revision], persistentRoot1Revision);
    UKObjectsNotEqual([persistentRoot2 revision], persistentRoot2Revision);
    UKObjectsEqual([persistentRoot1 revision], [persistentRoot1Revision parentRevision]);
    UKObjectsEqual([persistentRoot2 revision], [persistentRoot2Revision parentRevision]);
}

- (void)testUndoSetCurrentVersionForBranchSelectiveUndo
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    {
        COObject *root = [persistentRoot rootObject];
        COObject *child = [[[persistentRoot editingBranch] objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];    
        [root insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: kCOContents];
        [ctx commitWithUndoStack: _setupStack];
        
        [root setValue: @"root" forProperty: kCOLabel];
        [ctx commitWithUndoStack: _rootEditStack];
        
        [child setValue: @"child" forProperty: kCOLabel];
        [ctx commitWithUndoStack: _childEditStack];
    }
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];

		[_rootEditStack setEditingContext: ctx2];
		[_childEditStack setEditingContext: ctx2];

        COObject *root = [ctx2persistentRoot rootObject];
        COObject *child = [[root valueForProperty: kCOContents] firstObject];
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
        
        // Selective undo
        [_rootEditStack undo];
        
        UKNil([root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
        
        // Selective undo    
        [_childEditStack undo];
        
        UKNil([root valueForProperty: kCOLabel]);
        UKNil([child valueForProperty: kCOLabel]);
        
        // Selective Redo
        [_rootEditStack redo];
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKNil([child valueForProperty: kCOLabel]);
        
        // Selective Redo
        [_childEditStack redo];
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
    }
}

- (void) testUndoCreateBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];
    [ctx commitWithUndoStack: _testStack];
        
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];

		[_testStack setEditingContext: ctx2];

        UKFalse([ctx2secondBranch isDeleted]);
        [_testStack undo];
        UKTrue([ctx2secondBranch isDeleted]);
        [_testStack redo];
        UKFalse([ctx2secondBranch isDeleted]);
    }
}

- (void) testUndoCreateBranchAndSetCurrent
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];
    [persistentRoot setCurrentBranch: secondBranch];
    [ctx commitWithUndoStack: _testStack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];

		[_testStack setEditingContext: ctx2];

        UKNotNil(ctx2secondBranch);
        UKFalse([ctx2secondBranch isDeleted]);
        [_testStack undo];
        UKTrue([ctx2secondBranch isDeleted]);
        [_testStack redo];
        UKFalse([ctx2secondBranch isDeleted]);
    }
}

- (void) testUndoDeleteBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];
    [ctx commit];
    
    [secondBranch setDeleted: YES];
    [ctx commitWithUndoStack: _testStack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];
		
		[_testStack setEditingContext: ctx2];
		
        UKTrue([ctx2secondBranch isDeleted]);
        [_testStack undo];
        UKFalse([ctx2secondBranch isDeleted]);
        [_testStack redo];
        UKTrue([ctx2secondBranch isDeleted]);
    }
}

- (void) testUndoSetBranchMetadata
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot currentBranch] setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
    [[persistentRoot currentBranch] setMetadata: D(@"world2", @"hello")];
    [ctx commitWithUndoStack: _testStack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];

		[_testStack setEditingContext: ctx2];

        UKObjectsEqual(D(@"world2", @"hello"), [[ctx2persistentRoot currentBranch] metadata]);
        [_testStack undo];
        UKObjectsEqual(D(@"world", @"hello"), [[ctx2persistentRoot currentBranch] metadata]);
        [_testStack redo];
        UKObjectsEqual(D(@"world2", @"hello"), [[ctx2persistentRoot currentBranch] metadata]);
    }
}

- (void) testUndoSetCurrentBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COBranch *originalBranch = [persistentRoot currentBranch];
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];    
    [[[secondBranch objectGraphContext] rootObject] setValue: @"hello2" forProperty: kCOLabel];
    [ctx commit];
    
    [persistentRoot setCurrentBranch: secondBranch];
    [ctx commitWithUndoStack: _testStack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COBranch *ctx2originalBranch = [ctx2persistentRoot branchForUUID: [originalBranch UUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];

		[_testStack setEditingContext: ctx2];

        UKObjectsEqual(ctx2secondBranch, [ctx2persistentRoot currentBranch]);
        UKObjectsEqual(@"hello2", [[ctx2persistentRoot rootObject] valueForProperty: kCOLabel]);
        
        [_testStack undo];
        
        UKObjectsEqual(ctx2originalBranch, [ctx2persistentRoot currentBranch]);
        UKObjectsEqual(@"hello", [[ctx2persistentRoot rootObject] valueForProperty: kCOLabel]);
        
        [_testStack redo];
        
        UKObjectsEqual(ctx2secondBranch, [ctx2persistentRoot currentBranch]);
        UKObjectsEqual(@"hello2", [[ctx2persistentRoot rootObject] valueForProperty: kCOLabel]);
    }
}

- (void) testUndoCreatePersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoStack: _testStack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
		
		[_testStack setEditingContext: ctx2];
		
        UKFalse([ctx2persistentRoot isDeleted]);
        [_testStack undo];
        UKTrue([ctx2persistentRoot isDeleted]);
        [_testStack redo];
        UKFalse([ctx2persistentRoot isDeleted]);
    }
}

- (void) testUndoDeletePersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    [persistentRoot setDeleted: YES];
    [ctx commitWithUndoStack: _testStack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];

		[_testStack setEditingContext: ctx2];

		UKTrue([ctx2persistentRoot isDeleted]);
        [_testStack undo];
        UKFalse([ctx2persistentRoot isDeleted]);
        [_testStack redo];
        UKTrue([ctx2persistentRoot isDeleted]);
    }
}

- (void) testStackAPI
{
    COUndoStack *testStack = [[COUndoStackStore defaultStore] stackForName: @"test"];
	[testStack setEditingContext: ctx];
    UKObjectsEqual(@[], [testStack undoNodes]);
    UKObjectsEqual(@[], [testStack redoNodes]);
    UKFalse([testStack canRedo]);
    UKFalse([testStack canUndo]);
    
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoStack: testStack];
    
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithUndoStack: testStack];
    
    UKIntsEqual(2, [[testStack undoNodes] count]);
    UKObjectsEqual(@[], [testStack redoNodes]);
    UKFalse([testStack canRedo]);
    UKTrue([testStack canUndo]);
    
    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [testStack undo];
    
    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
}

- (void) testPatternStack
{
    COPersistentRoot *doc1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *doc2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoStack: _setupStack];

    COUndoStack *workspaceStack = [[COUndoStackStore defaultStore] stackForPattern: @"workspace.%"];
	[workspaceStack setEditingContext: ctx];
    COUndoStack *workspaceDoc1Stack = [[COUndoStackStore defaultStore] stackForName: @"workspace.doc1"];
	[workspaceDoc1Stack setEditingContext: ctx];
    COUndoStack *workspaceDoc2Stack = [[COUndoStackStore defaultStore] stackForName: @"workspace.doc2"];
	[workspaceDoc2Stack setEditingContext: ctx];
    [workspaceStack clear];

    // doc1 commits
    
    [[doc1 rootObject] setLabel: @"doc1"];
    [ctx commitWithUndoStack: workspaceDoc1Stack];
    [[doc1 rootObject] setLabel: @"sketch"];
    [ctx commitWithUndoStack: workspaceDoc1Stack];

    // doc2 commits
    
    [[doc2 rootObject] setLabel: @"doc2"];
    [ctx commitWithUndoStack: workspaceDoc2Stack];
    [[doc2 rootObject] setLabel: @"photo"];
    [ctx commitWithUndoStack: workspaceDoc2Stack];

    // experiment...

    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);
    [workspaceStack undo];
    UKObjectsEqual(@"doc2", [[doc2 rootObject] label]);
    
    [workspaceStack undo];
    UKNil([[doc2 rootObject] label]);

    UKObjectsEqual(@"sketch", [[doc1 rootObject] label]);
    [workspaceStack undo];
    UKObjectsEqual(@"doc1", [[doc1 rootObject] label]);
    
    [workspaceStack undo];
    UKNil([[doc1 rootObject] label]);
    
    // redo on doc2
    
    [workspaceDoc2Stack redo];
    UKNil([[doc1 rootObject] label]);
    UKObjectsEqual(@"doc2", [[doc2 rootObject] label]);

    [workspaceDoc2Stack redo];
    UKNil([[doc1 rootObject] label]);
    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);

    // redo on doc1
    
    [workspaceDoc1Stack redo];
    UKObjectsEqual(@"doc1", [[doc1 rootObject] label]);
    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);

    [workspaceDoc1Stack redo];
    UKObjectsEqual(@"sketch", [[doc1 rootObject] label]);
    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);
}

@end
