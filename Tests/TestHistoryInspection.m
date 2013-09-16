#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestHistoryInspection : EditingContextTestCase <UKTest>
{
    COPersistentRoot *p1;
    COBranch *br1a;
    COBranch *br1b;
    
    COPersistentRoot *p2;
    COBranch *br2a;
    
    CORevision *r0;
    CORevision *r1;
    CORevision *r2;
    CORevision *r3;
    CORevision *r4;
}
@end

@implementation TestHistoryInspection

/*

                                              __________ <<persistent root p1, branch br1b>>
                                             /
                                            v
                      
                               ------------0
                              /
                    0--------0------0--------------0
 
                                    ^              ^
                                     \              \_______  <<persistent root p2>>
                                      \
                                       \_____________________ <<persistent root p1, branch br1a>>
 
 
 
                    r0       r1     r2     r3      r4
 
 
 root obj label:  "null"    "1"    "2"    "3"     "4"
 
     initially
     committed     p1        p1     p1     p1      p2
 in persistent
          root:

     initially
  committed on    br1a      br1a   br1a   br1b    br2a
        branch:
 
 */

- (id) init
{
    SUPERINIT;
    p1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commit];
    
    br1a = [p1 currentBranch];
    r0 = [br1a currentRevision];
    [[p1 rootObject] setLabel: @"1"];
    [ctx commit];
    r1 = [br1a currentRevision];
    
    [[br1a rootObject] setLabel: @"2"];
    [ctx commit];
    r2 = [br1a currentRevision];
    
    br1b = [br1a makeBranchWithLabel: @"alternate" atRevision: r1];
    [[br1b rootObject] setLabel: @"3"];
    [ctx commit];
    r3 = [br1b currentRevision];
    
    p2 = [br1a makeCopyFromRevision: r2];
    [ctx commit]; // FIXME: This commit is a hack, should be removed. add test and fix.
    br2a = [p2 currentBranch];
    [[p2 rootObject] setLabel: @"4"];
    [ctx commit];
    r4 = [br2a currentRevision];
    
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
   UKObjectsEqual(r1, [r3 parentRevision]);
   UKObjectsEqual(r2, [r4 parentRevision]);
   UKObjectsEqual(r1, [r2 parentRevision]);
   UKObjectsEqual(r0, [r1 parentRevision]);
}

#if 0
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
    UKObjectsEqual([br1a UUID], [r0 branchUUID]);
    UKObjectsEqual([br1a UUID], [r1 branchUUID]);
    UKObjectsEqual([br1a UUID], [r2 branchUUID]);
    UKObjectsEqual([br1b UUID], [r3 branchUUID]);
    UKObjectsEqual([br2a UUID], [r4 branchUUID]);
}
#endif

@end