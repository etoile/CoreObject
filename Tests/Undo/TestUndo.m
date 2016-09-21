/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

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

    UKNil([persistentRoot.rootObject valueForProperty: kCOLabel]);
    
    [persistentRoot.rootObject setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithUndoTrack: _testTrack];
	
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual(@"hello", [testProot.rootObject valueForProperty: kCOLabel]);
	 }];
    
    [_testTrack undo];

	[self checkPersistentRootWithExistingAndNewContext: persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKNil([testProot.rootObject valueForProperty: kCOLabel]);
	 }];
}

- (void)testUndoSetCurrentVersionForBranchMultiplePersistentRoots
{
    COPersistentRoot *persistentRoot1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COPersistentRoot *persistentRoot2 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _testTrack];
    
    [persistentRoot1.rootObject setLabel: @"hello1"];
    [persistentRoot2.rootObject setLabel: @"hello2"];
    [ctx commitWithUndoTrack: _testTrack];
    
    CORevision *persistentRoot1Revision = persistentRoot1.currentRevision;
    CORevision *persistentRoot2Revision = persistentRoot2.currentRevision;
    
    [_testTrack undo];
    
	[self checkPersistentRootWithExistingAndNewContext: persistentRoot1
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot1, COBranch *testBranch, BOOL isNewContext)
	 {
		 COPersistentRoot *testProot2 = [testCtx persistentRootForUUID: persistentRoot2.UUID];
		 
		 UKObjectsNotEqual(testProot1.currentRevision, persistentRoot1Revision);
		 UKObjectsNotEqual(testProot2.currentRevision, persistentRoot2Revision);
		 UKObjectsEqual(testProot1.currentRevision, persistentRoot1Revision.parentRevision);
		 UKObjectsEqual(testProot2.currentRevision, persistentRoot2Revision.parentRevision);
	 }];
}

- (void)testUndoSetCurrentVersionForBranchSelectiveUndo
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    {
        COObject *root = persistentRoot.rootObject;
        COObject *child = [persistentRoot.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
        [root insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: kCOContents];
        [ctx commitWithIdentifier: @"insert-item" undoTrack: _setupTrack error: NULL];
        
        [root setValue: @"root" forProperty: kCOLabel];
        [ctx commitWithIdentifier: @"rename-item" undoTrack: _rootEditTrack error: NULL];
        
        [child setValue: @"child" forProperty: kCOLabel];
        [ctx commitWithIdentifier: @"rename-item" undoTrack: _childEditTrack error: NULL];
    }
    
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];

		COUndoTrack *rootEditTrack = [_rootEditTrack trackWithEditingContext: ctx2];
		COUndoTrack *childEditTrack = [_childEditTrack trackWithEditingContext: ctx2];

        COObject *root = ctx2persistentRoot.rootObject;
        COObject *child = [[root valueForProperty: kCOContents] firstObject];
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
        
		CORevision *r3 = ctx2persistentRoot.currentRevision;
		CORevision *r2 = r3.parentRevision;

		rootEditTrack.customRevisionMetadata = @{ @"extraKey" : @"extraValue" };
		
		//
        // First Selective undo
		//

        [rootEditTrack undo];
        
        UKNil([root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
        
		// Check that a new revision was created
		CORevision *r4 = ctx2persistentRoot.currentRevision;
		UKObjectsNotEqual(r3, r4);
		UKObjectsEqual(r3, r4.parentRevision);
		UKObjectsEqual(r2.metadata[kCOCommitMetadataIdentifier], r4.metadata[kCOCommitMetadataIdentifier]);

		UKObjectsEqual(@"org.etoile.CoreObject.undo", r4.metadata[kCOCommitMetadataUndoType]);
		UKObjectsEqual([[_rootEditTrack.nodes[1] UUID] stringValue], r4.metadata[kCOCommitMetadataUndoBaseUUID]);
		UKTrue([r4.metadata[kCOCommitMetadataUndoInitialBaseInversed] boolValue]);

		UKObjectsEqual(@"extraValue", r4.metadata[@"extraKey"]);
		
		//
        // Second Selective undo
		//
        [childEditTrack undo];
        
		// Check that a new revision was created
		CORevision *r5 = ctx2persistentRoot.currentRevision;
		UKObjectsEqual(r4, r5.parentRevision);
		UKObjectsEqual(r3.metadata[kCOCommitMetadataIdentifier], r5.metadata[kCOCommitMetadataIdentifier]);

		UKObjectsEqual(@"org.etoile.CoreObject.undo", r5.metadata[kCOCommitMetadataUndoType]);
		UKObjectsEqual([[_childEditTrack.nodes[1] UUID] stringValue], r5.metadata[kCOCommitMetadataUndoBaseUUID]);
		UKTrue([r5.metadata[kCOCommitMetadataUndoInitialBaseInversed] boolValue]);
		
        UKNil([root valueForProperty: kCOLabel]);
        UKNil([child valueForProperty: kCOLabel]);
        
		//
        // First selective redo
		//
        [rootEditTrack redo];
        
		// Check that a new revision was created
		CORevision *r6 = ctx2persistentRoot.currentRevision;
		UKObjectsEqual(r5, r6.parentRevision);
		UKObjectsEqual(r4.metadata[kCOCommitMetadataIdentifier], r6.metadata[kCOCommitMetadataIdentifier]);

		UKObjectsEqual(@"org.etoile.CoreObject.redo", r6.metadata[kCOCommitMetadataUndoType]);
		UKObjectsEqual([[_rootEditTrack.nodes[1] UUID] stringValue], r6.metadata[kCOCommitMetadataUndoBaseUUID]);
		UKFalse([r6.metadata[kCOCommitMetadataUndoInitialBaseInversed] boolValue]);

        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKNil([child valueForProperty: kCOLabel]);
        
		//
        // Second selective redo
		//
        [childEditTrack redo];
		
		// Check that a new revision was created
		CORevision *r7 = ctx2persistentRoot.currentRevision;
		UKObjectsEqual(r6, r7.parentRevision);
		UKObjectsEqual(r5.metadata[kCOCommitMetadataIdentifier], r7.metadata[kCOCommitMetadataIdentifier]);

		UKObjectsEqual(@"org.etoile.CoreObject.redo", r7.metadata[kCOCommitMetadataUndoType]);
		UKObjectsEqual([[_childEditTrack.nodes[1] UUID] stringValue], r7.metadata[kCOCommitMetadataUndoBaseUUID]);
		UKFalse([r7.metadata[kCOCommitMetadataUndoInitialBaseInversed] boolValue]);
        
        UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
        UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
    }
}

- (void) testUndoCreateBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [persistentRoot.currentBranch makeBranchWithLabel: @"secondBranch"];
    [ctx commitWithUndoTrack: _testTrack];
        
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: secondBranch.UUID];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKFalse(ctx2secondBranch.deleted);
        [testTrack undo];
        UKTrue(ctx2secondBranch.deleted);
        [testTrack redo];
        UKFalse(ctx2secondBranch.deleted);
    }
}

- (void) testUndoCreateBranchWithMetadata
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [persistentRoot.currentBranch makeBranchWithLabel: @"secondBranch"];
	secondBranch.metadata = @{ @"some" : @"metadata" };
    [ctx commitWithUndoTrack: _testTrack];
	
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: secondBranch.UUID];
		
		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKFalse(ctx2secondBranch.deleted);
        [testTrack undo];
        UKTrue(ctx2secondBranch.deleted);
        [testTrack redo];
        UKFalse(ctx2secondBranch.deleted);
    }
}

- (void) testUndoCreateBranchAndSetCurrent
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [persistentRoot.currentBranch makeBranchWithLabel: @"secondBranch"];
    persistentRoot.currentBranch = secondBranch;
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: secondBranch.UUID];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKNotNil(ctx2secondBranch);
        UKFalse(ctx2secondBranch.deleted);
        [testTrack undo];
        UKTrue(ctx2secondBranch.deleted);
        [testTrack redo];
        UKFalse(ctx2secondBranch.deleted);
    }
}

- (void) testUndoDeleteBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    COBranch *secondBranch = [persistentRoot.currentBranch makeBranchWithLabel: @"secondBranch"];
    [ctx commit];
    
    [secondBranch setDeleted: YES];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: secondBranch.UUID];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKTrue(ctx2secondBranch.deleted);
        [testTrack undo];
        UKFalse(ctx2secondBranch.deleted);
        [testTrack redo];
        UKTrue(ctx2secondBranch.deleted);
    }
}

- (void) testUndoSetBranchMetadata
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [persistentRoot.currentBranch setMetadata: D(@"world", @"hello")];
    [ctx commit];
    
    [persistentRoot.currentBranch setMetadata: D(@"world2", @"hello")];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKObjectsEqual(D(@"world2", @"hello"), [ctx2persistentRoot.currentBranch metadata]);
        [testTrack undo];
        UKObjectsEqual(D(@"world", @"hello"), [ctx2persistentRoot.currentBranch metadata]);
        [testTrack redo];
        UKObjectsEqual(D(@"world2", @"hello"), [ctx2persistentRoot.currentBranch metadata]);
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
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
		
		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKObjectsEqual(D(@"world2", @"hello"), ctx2persistentRoot.metadata);
        [testTrack undo];
        UKObjectsEqual(D(@"world", @"hello"), ctx2persistentRoot.metadata);
        [testTrack redo];
        UKObjectsEqual(D(@"world2", @"hello"), ctx2persistentRoot.metadata);
    }
}

- (void) testUndoSetCurrentBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COBranch *originalBranch = persistentRoot.currentBranch;
    [persistentRoot.rootObject setValue: @"hello" forProperty: kCOLabel];
    [ctx commit];
    
    COBranch *secondBranch = [persistentRoot.currentBranch makeBranchWithLabel: @"secondBranch"];    
    [secondBranch.objectGraphContext.rootObject setValue: @"hello2" forProperty: kCOLabel];
    [ctx commit];
    
    persistentRoot.currentBranch = secondBranch;
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
        COBranch *ctx2originalBranch = [ctx2persistentRoot branchForUUID: originalBranch.UUID];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: secondBranch.UUID];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

        UKObjectsEqual(ctx2secondBranch, ctx2persistentRoot.currentBranch);
        UKObjectsEqual(@"hello2", [ctx2persistentRoot.rootObject valueForProperty: kCOLabel]);
        
        [testTrack undo];
        
        UKObjectsEqual(ctx2originalBranch, ctx2persistentRoot.currentBranch);
        UKObjectsEqual(@"hello", [ctx2persistentRoot.rootObject valueForProperty: kCOLabel]);
        
        [testTrack redo];
        
        UKObjectsEqual(ctx2secondBranch, ctx2persistentRoot.currentBranch);
        UKObjectsEqual(@"hello2", [ctx2persistentRoot.rootObject valueForProperty: kCOLabel]);
    }
}

- (void) testUndoCreatePersistentRoot
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
		
		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKFalse(ctx2persistentRoot.deleted);
        [testTrack undo];
        UKTrue(ctx2persistentRoot.deleted);
        [testTrack redo];
        UKFalse(ctx2persistentRoot.deleted);
    }
}

- (void) testUndoCreatePersistentRootWithMetadata
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	persistentRoot.metadata = @{ @"some" : @"new metadata" };
    [ctx commitWithUndoTrack: _testTrack];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];
		
		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];
		
        UKFalse(ctx2persistentRoot.deleted);
        [testTrack undo];
        UKTrue(ctx2persistentRoot.deleted);
        [testTrack redo];
        UKFalse(ctx2persistentRoot.deleted);
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
        COEditingContext *ctx2 = [self newContext];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: persistentRoot.UUID];

		COUndoTrack *testTrack = [_testTrack trackWithEditingContext: ctx2];

		UKTrue(ctx2persistentRoot.deleted);
        [testTrack undo];
        UKFalse(ctx2persistentRoot.deleted);
        [testTrack redo];
        UKTrue(ctx2persistentRoot.deleted);
    }
}

- (void) testTrackAPI
{
    UKIntsEqual(1, [_testTrack.nodes count]); // Placeholder node
    UKFalse([_testTrack canRedo]);
    UKFalse([_testTrack canUndo]);
    
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithUndoTrack: _testTrack];
    
    [persistentRoot.rootObject setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithUndoTrack: _testTrack];
    
    UKIntsEqual(3, [_testTrack.nodes count]);
    UKIntsEqual(2, [_testTrack.nodes indexOfObject: [_testTrack currentNode]]);
    UKFalse([_testTrack canRedo]);
    UKTrue([_testTrack canUndo]);
    
    UKObjectsEqual(@"hello", [persistentRoot.rootObject valueForProperty: kCOLabel]);
    
    [_testTrack undo];
    
    UKNil([persistentRoot.rootObject valueForProperty: kCOLabel]);
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
    
    [doc1.rootObject setLabel: @"doc1"];
    [ctx commitWithUndoTrack: workspaceDoc1Track];
    [doc1.rootObject setLabel: @"sketch"];
    [ctx commitWithUndoTrack: workspaceDoc1Track];

    // doc2 commits
    
    [doc2.rootObject setLabel: @"doc2"];
    [ctx commitWithUndoTrack: workspaceDoc2Track];
    [doc2.rootObject setLabel: @"photo"];
    [ctx commitWithUndoTrack: workspaceDoc2Track];

    // experiment...

    UKObjectsEqual(@"photo", [doc2.rootObject label]);
    [workspaceTrack undo];
    UKObjectsEqual(@"doc2", [doc2.rootObject label]);
    
    [workspaceTrack undo];
    UKNil([doc2.rootObject label]);

    UKObjectsEqual(@"sketch", [doc1.rootObject label]);
    [workspaceTrack undo];
    UKObjectsEqual(@"doc1", [doc1.rootObject label]);
    
    [workspaceTrack undo];
    UKNil([doc1.rootObject label]);
    
    // redo on doc2
    
    [workspaceDoc2Track redo];
    UKNil([doc1.rootObject label]);
    UKObjectsEqual(@"doc2", [doc2.rootObject label]);

    [workspaceDoc2Track redo];
    UKNil([doc1.rootObject label]);
    UKObjectsEqual(@"photo", [doc2.rootObject label]);

    // redo on doc1
    
    [workspaceDoc1Track redo];
    UKObjectsEqual(@"doc1", [doc1.rootObject label]);
    UKObjectsEqual(@"photo", [doc2.rootObject label]);

    [workspaceDoc1Track redo];
    UKObjectsEqual(@"sketch", [doc1.rootObject label]);
    UKObjectsEqual(@"photo", [doc2.rootObject label]);
}

- (void) testSelectiveUndoOfCommands
{
    COPersistentRoot *doc1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *root = doc1.rootObject;
	OutlineItem *child1 = [doc1.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[root addObject: child1];
	
    [ctx commitWithUndoTrack: _setupTrack];
		
    // make some commits...
    
    root.label = @"doc1";
    [ctx commitWithUndoTrack: _testTrack];
	id<COTrackNode> node0 = _testTrack.nodes.lastObject;

    child1.label = @"child1";
    [ctx commitWithUndoTrack: _testTrack];
    id<COTrackNode> node1 = _testTrack.nodes.lastObject;
	
	root.label = @"doc1a";
    [ctx commitWithUndoTrack: _testTrack];
    id<COTrackNode> node2 = _testTrack.nodes.lastObject;
	
	child1.label = @"child1a";
    [ctx commitWithUndoTrack: _testTrack];
	id<COTrackNode> node3 = _testTrack.nodes.lastObject;
	
	UKObjectsEqual(@"doc1a", [root label]);
	UKObjectsEqual(@"child1a", [child1 label]);
	
    [_testTrack undoNode: node2]; // selective undo doc1 -> doc1a
	id<COTrackNode> node4 = _testTrack.nodes.lastObject;
	
	UKObjectsEqual(@"doc1", [root label]);
	UKObjectsEqual(@"child1a", [child1 label]);

	[_testTrack undo]; // undo the above -undoNode
	
	UKObjectsEqual(node3, [_testTrack currentNode]);
	UKObjectsEqual(@"doc1a", [root label]);
	UKObjectsEqual(@"child1a", [child1 label]);
	
	[_testTrack undo]; // undo child1 -> child1a
	
	UKObjectsEqual(node2, [_testTrack currentNode]);
	UKObjectsEqual(@"doc1a", [root label]);
	UKObjectsEqual(@"child1", [child1 label]);
	
	[_testTrack undo]; // undo doc1 -> doc1a
	
	UKObjectsEqual(node1, [_testTrack currentNode]);
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
	NSArray *subCommands = ((COCommandGroup *)aCommand).contents;
	UKIntsEqual(1, subCommands.count);
	
	COCommandSetCurrentVersionForBranch *command = subCommands.firstObject;
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
	OutlineItem *root = doc1.rootObject;
	[ctx commit];
	CORevision *r0 = doc1.currentRevision;
	
	OutlineItem *child1 = [doc1.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[root addObject: child1];
	[ctx commitWithIdentifier: @"insert-item" undoTrack: _testTrack error: nil];
	CORevision *r1 = doc1.currentRevision;
	
	OutlineItem *child2 = [doc1.objectGraphContext insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[root addObject: child2];
	[ctx commitWithIdentifier: @"insert-item" undoTrack: _testTrack error: nil];
	CORevision *r2 = doc1.currentRevision;
	
	UKObjectsEqual((@[child1, child2]), root.contents);
	
	// Check track contents
	UKIntsEqual(2, [_testTrack.nodes indexOfObject: [_testTrack currentNode]]);
	UKIntsEqual(3, _testTrack.nodes.count);
	[self checkCommandIsEndOfTrack: _testTrack.nodes[0]];
	[self checkCommand: _testTrack.nodes[1] isSetVersionFrom: r0 to: r1];
	[self checkCommand: _testTrack.nodes[2] isSetVersionFrom: r1 to: r2];
	
	_testTrack.customRevisionMetadata = @{ @"extraKey" : @"extraValue" };
	
	// selective undo child1 insertion
	[_testTrack undoNode: _testTrack.nodes[1]];
	CORevision *r3 = doc1.currentRevision;
	
	UKObjectsEqual(@[child2], root.contents);
	
	// Check track contents
	UKIntsEqual(3, [_testTrack.nodes indexOfObject: [_testTrack currentNode]]);
	UKIntsEqual(4, _testTrack.nodes.count);
	[self checkCommandIsEndOfTrack: _testTrack.nodes[0]];
	[self checkCommand: _testTrack.nodes[1] isSetVersionFrom: r0 to: r1];
	[self checkCommand: _testTrack.nodes[2] isSetVersionFrom: r1 to: r2];
	
	// This is the undo track node generated by undoNode:.
	// We've switched back and forth between recording the command as r2->r3 and
	// r1->r0. Recording it as r2->r3 is safer because if the selective undo has
	// undesirable results, you can undo it and be guarantee to be returned to r2.
	[self checkCommand: _testTrack.nodes[3] isSetVersionFrom: r2 to: r3];
	
	// Check that the commit created by COUndoTrack has proper commit metadata
	// FIXME: This next line tests the undo track node metadata, not the revision metadata.
	UKStringsEqual([_testTrack.nodes[1] metadata][kCOCommitMetadataIdentifier],
	               [_testTrack.nodes[3] metadata][kCOCommitMetadataIdentifier]);
	UKStringsEqual(@"org.etoile.CoreObject.selective-undo",
	              [_testTrack.nodes[3] metadata][kCOCommitMetadataUndoType]);
	UKStringsEqual([[_testTrack.nodes[1] UUID] stringValue],
	               [_testTrack.nodes[3] metadata][kCOCommitMetadataUndoBaseUUID]);
	UKTrue([[_testTrack.nodes[3] metadata][kCOCommitMetadataUndoInitialBaseInversed] boolValue]);
	UKObjectsEqual(@"extraValue", doc1.currentRevision.metadata[@"extraKey"]);
	
	// Efficiency test: the r3 commit should only have written one item to the store
	// (root) since that was the only change.
	COItemGraph *r3PartialItemGraph = [ctx.store partialItemGraphFromRevisionUUID: r2.UUID toRevisionUUID: r3.UUID persistentRoot: doc1.UUID];
	UKObjectsEqual(@[root.UUID], r3PartialItemGraph.itemUUIDs);
	
	// selective redo child1 insertion
	[_testTrack redoNode: _testTrack.nodes[1]];
	
	// Since the diffs will be [] -> [ child1 ]   +    [] -> [ child2 ], we can
	// get either [ child2, child1 ] or [ child1, child2 ]
	//
	UKObjectsEqual(S(child1.UUID, child2.UUID), SA([root valueForKeyPath: @"contents.UUID"]));
	UKStringsEqual([_testTrack.nodes[1] metadata][kCOCommitMetadataIdentifier],
	               [_testTrack.nodes[4] metadata][kCOCommitMetadataIdentifier]);
	UKStringsEqual(@"org.etoile.CoreObject.selective-redo",
	              [_testTrack.nodes[4] metadata][kCOCommitMetadataUndoType]);
	UKStringsEqual([[_testTrack.nodes[1] UUID] stringValue],
	               [_testTrack.nodes[4] metadata][kCOCommitMetadataUndoBaseUUID]);
	UKFalse([[_testTrack.nodes[4] metadata][kCOCommitMetadataUndoInitialBaseInversed] boolValue]);
}

- (void)testUndoCoalescing
{
	CORevision *r0, *r1, *r2, *r3, *r4, *r5, *r6;
    OutlineItem *item = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    [ctx commit];
	r0 = item.revision;
	
	// First coalesced block
	
	[_testTrack beginCoalescing];
	{
		item.label = @"a";
		[ctx commitWithUndoTrack: _testTrack];
		r1 = item.revision;
		
		item.label = @"ab";
		[ctx commitWithUndoTrack: _testTrack];
		r2 = item.revision;
	}
	[_testTrack endCoalescing];

	// N.B. Intentionally calling -nodes, which has the side effect of causing
	// COUndoTrack to cache the nodes in memory, to try to break things
	UKIntsEqual(2, [_testTrack.nodes count]);
	
	// Second coalesced block
	
	[_testTrack beginCoalescing];
	{
		item.label = @"abc";
		[ctx commitWithUndoTrack: _testTrack];
		r3 = item.revision;
		
		item.label = @"abcd";
		[ctx commitWithUndoTrack: _testTrack];
		r4 = item.revision;
	}
	[_testTrack endCoalescing];

	// Two more non-colesced commits
	
	item.label = @"foo";
	[ctx commitWithUndoTrack: _testTrack];
	r5 = item.revision;
	
	item.label = @"bar";
	[ctx commitWithUndoTrack: _testTrack];
	r6 = item.revision;

	// Check track contents
	UKIntsEqual(4, [_testTrack.nodes indexOfObject: [_testTrack currentNode]]);
	UKIntsEqual(5, _testTrack.nodes.count);
	[self checkCommandIsEndOfTrack: _testTrack.nodes[0]];
	[self checkCommand: _testTrack.nodes[1] isSetVersionFrom: r0 to: r2];
	[self checkCommand: _testTrack.nodes[2] isSetVersionFrom: r2 to: r4];
	[self checkCommand: _testTrack.nodes[3] isSetVersionFrom: r4 to: r5];
	[self checkCommand: _testTrack.nodes[4] isSetVersionFrom: r5 to: r6];
}

- (void)testUndoDisablesCoalescing
{
    OutlineItem *item = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    [ctx commit];
	
	[_testTrack beginCoalescing];

	UKTrue(_testTrack.coalescing);
		
	item.label = @"a";
	[ctx commitWithUndoTrack: _testTrack];

	UKTrue(_testTrack.coalescing);
	
	[_testTrack undo];
	
	UKFalse(_testTrack.coalescing);
}

- (void) testSelectiveUndoCommitDescriptor
{
	UKNotNil([COCommitDescriptor registeredDescriptorForIdentifier: @"org.etoile.CoreObject.selective-undo"]);
}

- (void) testSelectiveRedoCommitDescriptor
{
	UKNotNil([COCommitDescriptor registeredDescriptorForIdentifier: @"org.etoile.CoreObject.selective-redo"]);
}

@end


@implementation COUndoTrack (TestAdditions)

- (COUndoTrack *)trackWithEditingContext: (COEditingContext *)aContext
{
	return [[self class] trackForName: self.name withEditingContext: aContext];
}

@end
