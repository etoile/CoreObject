#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestHistoryInspection : EditingContextTestCase <UKTest>
{
    COPersistentRoot *p1;
    COBranch *branch1A;
    COBranch *branch1B;
	COBranch *branch1C;

    COPersistentRoot *p2;
    COBranch *branch2A;
    
    CORevision *r0;
    CORevision *r1;
    CORevision *r2;
    CORevision *r3;
    CORevision *r4;
    CORevision *r5;
	CORevision *r6;
    CORevision *r7;
    CORevision *r8;
	CORevision *r9;
	CORevision *r10;
}
@end

@implementation TestHistoryInspection

/*
                                                    -[7]-----------[9]         )
                                                   /                           }--  persistent root p1, branch 1C
                                                --------------------------10   )       (current revision: r10)
		                                       /
		                        ---[5]        /   ------[8]    )
                               /             /   /             }-- persistent root p1, branch 1B
		   ------------3-----------------6-------              )      (current revision: r6)
		  /
  0------1------2    }-- persistent root p1, branch 1A (current revision: r2)
				 \
				  ------------4    <-- persistent root p2, branch 2A (current revision: r4)

 

           revision:  r0      r1      r2     r3     r4     r5     r6     r7     r8     r9     r10
 
  root object label:  "null"  "1"     "2"    "3"    "4"    "5"    "6"    "7"    "8"    "9"    "10"
 
    persistent root:  p1      p1      p1     p1     p2     p1     p1     p1     p1     p1     p1
 
             branch:  1A      1A      1A     1B     2A     1B     1B     1C     1B     1C     1C
 
 
 
  Notes: Divergent revisions are enclosed in [].
  Divergent revisions are revisions which are not ancestors of the current revision
  of a branch, but in the past they were comitted on that branch.
 
  A commit creates a new revision and changes the current revision, but changing
  the current revision doesn't result in a new revision.
 
 */

- (id) init
{
    SUPERINIT;
    p1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    branch1A = [p1 currentBranch];
    r0 = [branch1A currentRevision];
    [[p1 rootObject] setLabel: @"1"];
    [ctx commit];
    r1 = [branch1A currentRevision];
    
    [[branch1A rootObject] setLabel: @"2"];
    [ctx commit];
    r2 = [branch1A currentRevision];
    
    branch1B = [branch1A makeBranchWithLabel: @"1B" atRevision: r1];

    [[branch1B rootObject] setLabel: @"3"];
    [ctx commit];
    r3 = [branch1B currentRevision];
    
    p2 = [branch1A makeCopyFromRevision: r2];
    [ctx commit]; // FIXME: This commit is a hack, should be removed. add test and fix.

    branch2A = [p2 currentBranch];
    [[p2 rootObject] setLabel: @"4"];
    [ctx commit];
    r4 = [branch2A currentRevision];

	[[branch1B rootObject] setLabel: @"5"];
    [ctx commit];
    r5 = [branch1B currentRevision];
	
    branch1B.currentRevision = r3;
    [ctx commit];
	
	[[branch1B rootObject] setLabel: @"6"];
    [ctx commit];
    r6 = [branch1B currentRevision];

	branch1C = [branch1B makeBranchWithLabel: @"1C" atRevision: r6];

    [[branch1C rootObject] setLabel: @"7"];
    [ctx commit];
    r7 = [branch1C currentRevision];

	[[branch1B rootObject] setLabel: @"8"];
    [ctx commit];
    r8 = [branch1B currentRevision];

	[[branch1C rootObject] setLabel: @"9"];
    [ctx commit];
    r9 = [branch1C currentRevision];

	branch1C.currentRevision = r6;
    [ctx commit];
    
	[[branch1C rootObject] setLabel: @"10"];
    [ctx commit];
    r10 = [branch1C currentRevision];

	branch1B.currentRevision = r6;
    [ctx commit];

    return self;
}

- (void) testRevisionContents
{
    UKObjectsEqual(@"4", [[[p2 objectGraphContextForPreviewingRevision: r4] rootObject] label]);
    UKObjectsEqual(@"3", [[[p1 objectGraphContextForPreviewingRevision: r3] rootObject] label]);
    UKObjectsEqual(@"2", [[[p1 objectGraphContextForPreviewingRevision: r2] rootObject] label]);
    UKObjectsEqual(@"1", [[[p1 objectGraphContextForPreviewingRevision: r1] rootObject] label]);
    UKNil([[[p1 objectGraphContextForPreviewingRevision: r0] rootObject] label]);
}

- (void) testRevisionParentRevision
{
	UKObjectsEqual(r1, [r2 parentRevision]);
	UKObjectsEqual(r1, [r3 parentRevision]);
	UKObjectsEqual(r2, [r4 parentRevision]);
	UKObjectsEqual(r3, [r5 parentRevision]);
	UKObjectsEqual(r3, [r6 parentRevision]);
	UKObjectsEqual(r6, [r7 parentRevision]);
	UKObjectsEqual(r6, [r8 parentRevision]);
	UKObjectsEqual(r7, [r9 parentRevision]);
	UKObjectsEqual(r6, [r10 parentRevision]);
}

- (void) testRevisionPersistentRootUUID
{
    UKObjectsEqual([p1 persistentRootUUID], [r0 persistentRootUUID]);
    UKObjectsEqual([p1 persistentRootUUID], [r1 persistentRootUUID]);
    UKObjectsEqual([p1 persistentRootUUID], [r2 persistentRootUUID]);
    UKObjectsEqual([p1 persistentRootUUID], [r3 persistentRootUUID]);
    UKObjectsEqual([p2 persistentRootUUID], [r4 persistentRootUUID]);
}

- (void) testRevisionBranchUUID
{
    UKObjectsEqual([branch1A UUID], [r0 branchUUID]);
    UKObjectsEqual([branch1A UUID], [r1 branchUUID]);
    UKObjectsEqual([branch1A UUID], [r2 branchUUID]);
    UKObjectsEqual([branch1B UUID], [r3 branchUUID]);
    UKObjectsEqual([branch2A UUID], [r4 branchUUID]);
}

- (void) testParentBranch
{
    UKObjectsEqual(branch1A, [branch1B parentBranch]);
    UKNil([branch1A parentBranch]);

    // FIXME: Decide what we want this to be
    UKNil([branch2A parentBranch]);
}

- (NSArray *)revisionsForBranch: (COBranch *)aBranch
                        options: (COBranchRevisionReadingOptions)options
{
	NSArray *revInfos = [[ctx store] revisionInfosForBranchUUID: [aBranch UUID]
	                                                    options: options];
	NSMutableArray *revs = [NSMutableArray array];
	
	for (CORevisionInfo *revInfo in revInfos)
	{
		[revs addObject: [[CORevision alloc] initWithEditingContext: ctx
                                                       revisionInfo: revInfo]];
	}
	return revs;
}

- (void)testBasicBranchRevisions
{
	UKObjectsEqual(A(r0, r1, r2), [self revisionsForBranch: branch1A options: 0]);
	UKObjectsEqual(A(r3, r6), [self revisionsForBranch: branch1B options: 0]);
	UKObjectsEqual(A(r10), [self revisionsForBranch: branch1C options: 0]);
	UKObjectsEqual(A(r4), [self revisionsForBranch: branch2A options: 0]);
}

- (void)testBranchRevisionsIncludingParentBranches
{
	COBranchRevisionReadingOptions options = COBranchRevisionReadingParentBranches;

	UKObjectsEqual(A(r0, r1, r2), [self revisionsForBranch: branch1A options: options]);
	UKObjectsEqual(A(r0, r1, r3, r6), [self revisionsForBranch: branch1B options: options]);
	UKObjectsEqual(A(r0, r1, r3, r6, r10), [self revisionsForBranch: branch1C options: options]);
	UKObjectsEqual(A(r0, r1, r2, r4), [self revisionsForBranch: branch2A options: options]);
}

- (void)testBranchRevisionsIncludingParentBranchesAndDivergentRevisions
{
	COBranchRevisionReadingOptions options =
		(COBranchRevisionReadingParentBranches | COBranchRevisionReadingDivergentRevisions);
	
	UKObjectsEqual(A(r0, r1, r2), [self revisionsForBranch: branch1A options: options]);
	/* Divergent revisions that follow the head revision are ignored (e.g. r8) */
	UKObjectsEqual(A(r0, r1, r3, r5, r6), [self revisionsForBranch: branch1B options: options]);
	UKObjectsEqual(A(r0, r1, r3, r5, r6, r7, r9, r10), [self revisionsForBranch: branch1C options: options]);
	UKObjectsEqual(A(r0, r1, r2, r4), [self revisionsForBranch: branch2A options: options]);
}

- (void) wait
{
	NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
	[runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
}

- (void)testBranchNodes
{
	UKObjectsEqual(A(r0, r1, r2, r4), [branch2A nodes]);
}

- (void)testBranchNodeUpdateForNewCommit
{
	/* Load the revision history (to support testing it it is updated in 
	   reaction to a commit) */
	[branch2A nodes];

    [[branch2A rootObject] setLabel: @"11"];
    [ctx commit];
    CORevision *r11 = [branch2A currentRevision];

	// FIXME: We shouldn't have to call -wait, this would be more convenient,
	// and more consistent with -currentRevision being updated immediately.
	[self wait];

	UKObjectsEqual(A(r0, r1, r2, r4, r11), [branch2A nodes]);
}

// FIXME: Test these things when reloading from a store

@end