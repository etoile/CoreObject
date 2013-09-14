#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestHistoryInspection : EditingContextTestCase <UKTest>
{
    COPersistentRoot *p1;
    COBranch *br1;
    COBranch *br2;
    
    COPersistentRoot *p2;
}
@end

@implementation TestHistoryInspection

/*

                                             __________ <<persistent root p1, branch br2>>
                                            /
                      
                               ------------0
                              /
                    0--------0------0
                                      \
                                       \______________ <<persistent root p1, branch br1>>
                                        \
                                         \____________ <<persistent root p2>>
 
 
 
 root obj label:  "null"    "1"    "2"   "2alt"
 
     initially
  committed on     br1      br1    br1    br2
        branch:
 
     initially
     committed     p1       p1     p1     p1
 in persistent
          root:
 
 */

- (id) init
{
    SUPERINIT;
    p1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    br1 = [p1 currentBranch];
    [[p1 rootObject] setLabel: @"1"];
    [ctx commit];
    
    br2 = [br1 makeBranchWithLabel: @"alternate"];
    [[br2 rootObject] setLabel: @"2alt"];
    
    [[br1 rootObject] setLabel: @"2"];
    [ctx commit];
    
    p2 = [br1 makeCopyFromRevision: [br1 currentRevision]];
    [ctx commit];
    
    return self;
}

@end