#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface COUndoTrack (TestAdditions)
- (COUndoTrack *)trackWithEditingContext: (COEditingContext *)aContext;
@end

@interface TestUndo : EditingContextTestCase <UKTest>
{
    COUndoTrack *_testTrack;
    COUndoTrack *_setupTrack;
    COUndoTrack *_rootEditTrack;
    COUndoTrack *_childEditTrack;
}
@end

@implementation TestUndo

- (id) init
{
    SUPERINIT;
    
    _testTrack = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    _setupTrack = [COUndoTrack trackForName: @"setup" withEditingContext: ctx];
    _rootEditTrack = [COUndoTrack trackForName: @"rootEdit" withEditingContext: ctx];
    _childEditTrack = [COUndoTrack trackForName: @"childEdit" withEditingContext: ctx];
    
    [_testTrack clear];
    [_setupTrack clear];
    [_rootEditTrack clear];
    [_childEditTrack clear];
    
    return self;
}


- (void)testUndoSetCurrentVersionForBranchBasic
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _testTrack];

    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithUndoTrack: _testTrack];
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@"hello", [[testProot rootObject] valueForProperty: kCOLabel]);
	 }];
    
    [_testTrack undo];

	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKNil([[testProot rootObject] valueForProperty: kCOLabel]);
	 }];
}

- (void)testUndoSetCurrentVersionForBranchMultiplePersistentRoots
{
    COPersistentRoot *persistentRoot1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _testTrack];
    
    [[persistentRoot1 rootObject] setLabel: @"hello1"];
    [[persistentRoot2 rootObject] setLabel: @"hello2"];
    [ctx commitWithUndoTrack: _testTrack];
    
    CORevision *persistentRoot1Revision = [persistentRoot1 currentRevision];
    CORevision *persistentRoot2Revision = [persistentRoot2 currentRevision];
    
    [_testTrack undo];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot1
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot1, COBranch *testBranch, BOOL isNewContext)
	 {
		 COPersistentRoot *testProot2 = [testCtx persistentRootForUUID: [persistentRoot2 UUID]];
		 
		 UKObjectsNotEqual([testProot1 currentRevision], persistentRoot1Revision);
		 UKObjectsNotEqual([testProot2 currentRevision], persistentRoot2Revision);
		 UKObjectsEqual([testProot1 currentRevision], [persistentRoot1Revision parentRevision]);
		 UKObjectsEqual([testProot2 currentRevision], [persistentRoot2Revision parentRevision]);
	 }];
}

- (void)testUndoSetCurrentVersionForBranchSelectiveUndo
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    {
        COObject *root = [persistentRoot rootObject];
        COObject *child = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
        [root insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: kCOContents];
        [ctx commitWithUndoTrack: _setupTrack];
        
        [root setValue: @"root" forProperty: kCOLabel];
        [ctx commitWithUndoTrack: _rootEditTrack];
        
        [child setValue: @"child" forProperty: kCOLabel];
        [ctx commitWithUndoTrack: _childEditTrack];
    }
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];

		COUndoTrack *rootEditTrack = [_rootEditTrack trackWithEditingContext: ctx2];
		COUndoTrack *childEditTrack = [_childEditTrack trackWithEditingContext: ctx2];

        COObject *root = [ctx2persistentRoot rootObject];
        COObject *child = [[root valueForProperty: kCOContents] firstObject];
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
        
        // Selective undo
        [rootEditTrack undo];
        
        UKNil([root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
        
        // Selective undo    
        [childEditTrack undo];
        
        UKNil([root valueForProperty: kCOLabel]);
        UKNil([child valueForProperty: kCOLabel]);
        
        // Selective Redo
        [rootEditTrack redo];
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKNil([child valueForProperty: kCOLabel]);
        
        // Selective Redo
        [childEditTrack redo];
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
    }
}

- (void) testUndoCreateBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];
    [ctx commitWithUndoTrack: _testTrack];
        
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKFalse([ctx2secondBranch isDeleted]);
        [testTrack undo];
        UKTrue([ctx2secondBranch isDeleted]);
        [testTrack redo];
        UKFalse([ctx2secondBranch isDeleted]);
    }
}

- (void) testUndoCreateBranchAndSetCurrent
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];
    [persistentRoot setCurrentBranch: secondBranch];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKNotNil(ctx2secondBranch);
        UKFalse([ctx2secondBranch isDeleted]);
        [testTrack undo];
        UKTrue([ctx2secondBranch isDeleted]);
        [testTrack redo];
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
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKTrue([ctx2secondBranch isDeleted]);
        [testTrack undo];
        UKFalse([ctx2secondBranch isDeleted]);
        [testTrack redo];
        UKTrue([ctx2secondBranch isDeleted]);
    }
}

- (void) testUndoSetBranchMetadata
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot currentBranch] setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
    [[persistentRoot currentBranch] setMetadata: D(@"world2", @"hello")];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKObjectsEqual(D(@"world2", @"hello"), [[ctx2persistentRoot currentBranch] metadata]);
        [testTrack undo];
        UKObjectsEqual(D(@"world", @"hello"), [[ctx2persistentRoot currentBranch] metadata]);
        [testTrack redo];
        UKObjectsEqual(D(@"world2", @"hello"), [[ctx2persistentRoot currentBranch] metadata]);
    }
}

- (void) testUndoSetPersistentRootMetadata
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [persistentRoot setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
    [persistentRoot setMetadata: D(@"world2", @"hello")];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		
		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKObjectsEqual(D(@"world2", @"hello"), [ctx2persistentRoot metadata]);
        [testTrack undo];
        UKObjectsEqual(D(@"world", @"hello"), [ctx2persistentRoot metadata]);
        [testTrack redo];
        UKObjectsEqual(D(@"world2", @"hello"), [ctx2persistentRoot metadata]);
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
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
        COBranch *ctx2originalBranch = [ctx2persistentRoot branchForUUID: [originalBranch UUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKObjectsEqual(ctx2secondBranch, [ctx2persistentRoot currentBranch]);
        UKObjectsEqual(@"hello2", [[ctx2persistentRoot rootObject] valueForProperty: kCOLabel]);
        
        [testTrack undo];
        
        UKObjectsEqual(ctx2originalBranch, [ctx2persistentRoot currentBranch]);
        UKObjectsEqual(@"hello", [[ctx2persistentRoot rootObject] valueForProperty: kCOLabel]);
        
        [testTrack redo];
        
        UKObjectsEqual(ctx2secondBranch, [ctx2persistentRoot currentBranch]);
        UKObjectsEqual(@"hello2", [[ctx2persistentRoot rootObject] valueForProperty: kCOLabel]);
    }
}

- (void) testUndoCreatePersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];
		
		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKFalse([ctx2persistentRoot isDeleted]);
        [testTrack undo];
        UKTrue([ctx2persistentRoot isDeleted]);
        [testTrack redo];
        UKFalse([ctx2persistentRoot isDeleted]);
    }
}

- (void) testUndoDeletePersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    [persistentRoot setDeleted: YES];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot UUID]];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

		UKTrue([ctx2persistentRoot isDeleted]);
        [testTrack undo];
        UKFalse([ctx2persistentRoot isDeleted]);
        [testTrack redo];
        UKTrue([ctx2persistentRoot isDeleted]);
    }
}

- (void) testTrackAPI
{
    UKIntsEqual(1, [[_testTrack nodes] count]); // Placeholder node
    UKFalse([_testTrack canRedo]);
    UKFalse([_testTrack canUndo]);
    
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _testTrack];
    
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithUndoTrack: _testTrack];
    
    UKIntsEqual(3, [[_testTrack nodes] count]);
    UKIntsEqual(2, [[_testTrack nodes] indexOfObject: [_testTrack currentNode]]);
    UKFalse([_testTrack canRedo]);
    UKTrue([_testTrack canUndo]);
    
    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [_testTrack undo];
    
    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
}

- (void) testPatternTrack
{
    COPersistentRoot *doc1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *doc2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _setupTrack];

    COUndoTrack *workspaceTrack = [COUndoTrack trackForPattern: @"workspace.*"
	                                        withEditingContext: ctx];
    COUndoTrack *workspaceDoc1Track = [COUndoTrack trackForName: @"workspace.doc1"
	                                         withEditingContext: ctx];
    COUndoTrack *workspaceDoc2Track = [COUndoTrack trackForName: @"workspace.doc2"
	                                         withEditingContext: ctx];
    [workspaceTrack clear];

    // doc1 commits
    
    [[doc1 rootObject] setLabel: @"doc1"];
    [ctx commitWithUndoTrack: workspaceDoc1Track];
    [[doc1 rootObject] setLabel: @"sketch"];
    [ctx commitWithUndoTrack: workspaceDoc1Track];

    // doc2 commits
    
    [[doc2 rootObject] setLabel: @"doc2"];
    [ctx commitWithUndoTrack: workspaceDoc2Track];
    [[doc2 rootObject] setLabel: @"photo"];
    [ctx commitWithUndoTrack: workspaceDoc2Track];

    // experiment...

    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);
    [workspaceTrack undo];
    UKObjectsEqual(@"doc2", [[doc2 rootObject] label]);
    
    [workspaceTrack undo];
    UKNil([[doc2 rootObject] label]);

    UKObjectsEqual(@"sketch", [[doc1 rootObject] label]);
    [workspaceTrack undo];
    UKObjectsEqual(@"doc1", [[doc1 rootObject] label]);
    
    [workspaceTrack undo];
    UKNil([[doc1 rootObject] label]);
    
    // redo on doc2
    
    [workspaceDoc2Track redo];
    UKNil([[doc1 rootObject] label]);
    UKObjectsEqual(@"doc2", [[doc2 rootObject] label]);

    [workspaceDoc2Track redo];
    UKNil([[doc1 rootObject] label]);
    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);

    // redo on doc1
    
    [workspaceDoc1Track redo];
    UKObjectsEqual(@"doc1", [[doc1 rootObject] label]);
    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);

    [workspaceDoc1Track redo];
    UKObjectsEqual(@"sketch", [[doc1 rootObject] label]);
    UKObjectsEqual(@"photo", [[doc2 rootObject] label]);
}

- (void) testSelectiveUndoOfCommands
{
    COPersistentRoot *doc1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *root = [doc1 rootObject];
	OutlineItem *child1 = [[doc1 objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[root addObject: child1];
	
    [ctx commitWithUndoTrack: _setupTrack];
		
    // make some commits...
    
    [root setLabel: @"doc1"];
    [ctx commitWithUndoTrack: _testTrack];
    [child1 setLabel: @"child1"];
    [ctx commitWithUndoTrack: _testTrack];
    [root setLabel: @"doc1a"];
    [ctx commitWithUndoTrack: _testTrack];
    [child1 setLabel: @"child1a"];
    [ctx commitWithUndoTrack: _testTrack];
	   
	id<COTrackNode> node = [[_testTrack nodes] objectAtIndex: ([_testTrack count] - 2)];

	UKObjectsEqual(@"doc1a", [root label]);
	UKObjectsEqual(@"child1a", [child1 label]);
	
    [_testTrack undoNode: node]; // selective undo doc1 -> doc1a

	UKObjectsEqual(@"doc1", [root label]);
	UKObjectsEqual(@"child1a", [child1 label]);

	[_testTrack undo]; // undo the above -undoNode
	
	UKObjectsEqual(@"doc1a", [root label]);
	UKObjectsEqual(@"child1a", [child1 label]);
	
	[_testTrack undo]; // undo child1 -> child1a
	
	UKObjectsEqual(@"doc1a", [root label]);
	UKObjectsEqual(@"child1", [child1 label]);
	
	[_testTrack undo]; // undo doc1 -> doc1a
	
	UKObjectsEqual(@"doc1", [root label]);
	UKObjectsEqual(@"child1", [child1 label]);
}

- (void) checkCommandIsEndOfTrack: (id<COTrackNode>)aCommand
{
	UKObjectsEqual([COEndOfUndoTrackPlaceholderNode sharedInstance], aCommand);
}

- (void) checkCommand: (id<COTrackNode>)aCommand
	 isSetVersionFrom: (CORevision *)a
				   to: (CORevision *)b
{
	NSArray *subCommands = [(COCommandGroup *)aCommand contents];
	UKIntsEqual(1, [subCommands count]);
	
	COCommandSetCurrentVersionForBranch *command = [subCommands firstObject];
	UKObjectKindOf(command, COCommandSetCurrentVersionForBranch);
	UKObjectsEqual(a, command.oldRevision);
	UKObjectsEqual(b, command.revision);
}

- (void) testSelectiveUndoOfCommands2
{
	/*
	
	 setup:                           |  test:
									  |
	 r0   r1        r2                |  r3
									  |
	 []   [child1]  [child1, child2]  |  [child2]
	                                  |
									  |  (selective undo of r0->r1)
	 */
	
    COPersistentRoot *doc1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *root = [doc1 rootObject];
	[ctx commit];
	CORevision *r0 = [doc1 currentRevision];
	
	OutlineItem *child1 = [[doc1 objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[root addObject: child1];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r1 = [doc1 currentRevision];
	
	OutlineItem *child2 = [[doc1 objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[root addObject: child2];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r2 = [doc1 currentRevision];
	
	UKObjectsEqual(ORDEREDSET(child1, child2), [root contents]);
	
	// Check track contents
	UKIntsEqual(2, [[_testTrack nodes] indexOfObject: [_testTrack currentNode]]);
	UKIntsEqual(3, [_testTrack.nodes count]);
	[self checkCommandIsEndOfTrack: _testTrack.nodes[0]];
	[self checkCommand: _testTrack.nodes[1] isSetVersionFrom: r0 to: r1];
	[self checkCommand: _testTrack.nodes[2] isSetVersionFrom: r1 to: r2];
	
	// selective undo child1 insertion
	[_testTrack undoNode: _testTrack.nodes[1]];
	CORevision *r3 = [doc1 currentRevision];
	
	UKObjectsEqual(ORDEREDSET(child2), [root contents]);
	
	// Check track contents
	UKIntsEqual(3, [[_testTrack nodes] indexOfObject: [_testTrack currentNode]]);
	UKIntsEqual(4, [_testTrack.nodes count]);
	[self checkCommandIsEndOfTrack: _testTrack.nodes[0]];
	[self checkCommand: _testTrack.nodes[1] isSetVersionFrom: r0 to: r1];
	[self checkCommand: _testTrack.nodes[2] isSetVersionFrom: r1 to: r2];
	[self checkCommand: _testTrack.nodes[3] isSetVersionFrom: r2 to: r3];
}

@end


@implementation COUndoTrack (TestAdditions)

- (COUndoTrack *)trackWithEditingContext: (COEditingContext *)aContext
{
	return [[self class] trackForName: [self name] withEditingContext: aContext];
}

@end
