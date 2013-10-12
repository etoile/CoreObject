#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

/**
 * These tests are simulate some real-world use cases, whereas TestUndo
 * tests feature-by-feature.
 */
@interface TestUndoUseCases : EditingContextTestCase <UKTest>
{
    COUndoTrack *_testTrack;
}
@end

@implementation TestUndoUseCases

- (id) init
{
    SUPERINIT;
    
    _testTrack = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    [_testTrack clear];

    return self;
}

/*
         ----r2b
	    /
 r0---r1---r2---r3
 

 (starting state: r0)
 
 states visited:
 r1
 r2
 r3
 r1
 r2b
 
 */
- (void) testRevertAndMakeDivergentCommit
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
	CORevision *r0 = [persistentRoot currentRevision];
	
	[[persistentRoot rootObject] setLabel: @"r1"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r1 = [persistentRoot currentRevision];
	
	[[persistentRoot rootObject] setLabel: @"r2"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r2 = [persistentRoot currentRevision];
	
	[[persistentRoot rootObject] setLabel: @"r3"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r3 = [persistentRoot currentRevision];

	persistentRoot.currentRevision = r1;
	[ctx commitWithUndoTrack: _testTrack];
	
	[[persistentRoot rootObject] setLabel: @"r2b"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r2b = [persistentRoot currentRevision];
	
	[_testTrack undo];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);
	[_testTrack undo];
	UKObjectsEqual(r3, [persistentRoot currentRevision]);
	[_testTrack undo];
	UKObjectsEqual(r2, [persistentRoot currentRevision]);
	[_testTrack undo];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);
	[_testTrack undo];
	UKObjectsEqual(r0, [persistentRoot currentRevision]);
	
	UKFalse([_testTrack canUndo]);
	
	[_testTrack redo];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);
	[_testTrack redo];
	UKObjectsEqual(r2, [persistentRoot currentRevision]);
	[_testTrack redo];
	UKObjectsEqual(r3, [persistentRoot currentRevision]);
	[_testTrack redo];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);
	[_testTrack redo];
	UKObjectsEqual(r2b, [persistentRoot currentRevision]);
	
	UKFalse([_testTrack canRedo]);
}

/*
        ----r2b
       /
 r0---r1---r2---r3
 
 */
- (void) testUndoAndBranchNavigation
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
	
	[[persistentRoot rootObject] setLabel: @"r1"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r1 = [persistentRoot currentRevision];
	
	[[persistentRoot rootObject] setLabel: @"r2"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r2 = [persistentRoot currentRevision];
	
	[[persistentRoot rootObject] setLabel: @"r3"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r3 = [persistentRoot currentRevision];
	
	[[persistentRoot currentBranch] undo];
	[ctx commitWithUndoTrack: _testTrack];
	UKObjectsEqual(r2, [persistentRoot currentRevision]);

	[[persistentRoot currentBranch] undo];
	[ctx commitWithUndoTrack: _testTrack];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);

	[[persistentRoot rootObject] setLabel: @"r2b"];
	[ctx commitWithUndoTrack: _testTrack];
	CORevision *r2b = [persistentRoot currentRevision];
	UKObjectsEqual(r2b, [[persistentRoot currentBranch] newestRevision]);
	UKObjectsNotEqual(r3, [[persistentRoot currentBranch] newestRevision]);
	
	[[persistentRoot currentBranch] undo];
	[ctx commitWithUndoTrack: _testTrack];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);

	[[persistentRoot currentBranch] redo];
	[ctx commitWithUndoTrack: _testTrack];
	UKObjectsEqual(r2b, [persistentRoot currentRevision]);

	// Switch to using track undo, instead of branch navigation
	
	[_testTrack undo];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);
	[_testTrack undo];
	UKObjectsEqual(r2b, [persistentRoot currentRevision]);
	UKObjectsEqual(r2b, [[persistentRoot currentBranch] newestRevision]);
	UKObjectsNotEqual(r3, [[persistentRoot currentBranch] newestRevision]);
	
	// The main point of the test is that the following -undo restores the
	// branch head_revid (-newestRevision) to point to r3, which means
	// [[persistentRoot currentBranch] redo] moves towards r3 instead of r2b.
	
	[_testTrack undo];
	UKObjectsEqual(r1, [persistentRoot currentRevision]);
	UKObjectsNotEqual(r2b, [[persistentRoot currentBranch] newestRevision]);
	UKObjectsEqual(r3, [[persistentRoot currentBranch] newestRevision]);

	[[persistentRoot currentBranch] redo];
	[ctx commitWithUndoTrack: _testTrack];
	UKObjectsEqual(r2, [persistentRoot currentRevision]);
	
	[[persistentRoot currentBranch] redo];
	[ctx commitWithUndoTrack: _testTrack];
	UKObjectsEqual(r3, [persistentRoot currentRevision]);
}

@end
