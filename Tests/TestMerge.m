#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestMerge : EditingContextTestCase <UKTest>
@end

@implementation TestMerge

/*
 
 
 
 */

- (void) testSimpleMerge
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    OutlineItem *rootObj = [persistentRoot rootObject];
    OutlineItem *childObj = [persistentRoot insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [rootObj insertObject: childObj atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [rootObj setLabel: @"0"];
    [childObj setLabel: @"0"];
    [ctx commit];
    
    COBranch *initialBranch = [persistentRoot currentBranch];
    COBranch *secondBranch = [initialBranch makeBranchWithLabel: @"second branch"];
    
    // initialBranch will edit rootObj's label
    // secondBranch will edit childObj's label
    
    [rootObj setLabel: @"1"];
    [(OutlineItem *)[[secondBranch objectGraphContext] objectWithUUID: [childObj UUID]] setLabel: @"2"];
    [ctx commit];
    
    {
        // Quick check that the commits worked
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *persistentRootCtx2 = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        
        CORevision *initialBranchRev = [persistentRootCtx2 revision];
        CORevision *secondBranchRev = [[persistentRootCtx2 branchForUUID: [secondBranch UUID]] currentRevision];
        CORevision *initialRev = [initialBranchRev parentRevision];
        
        // Check for the proper relationship
        
        UKObjectsEqual(initialRev, [secondBranchRev parentRevision]);
        
        UKObjectsNotEqual(initialBranchRev, secondBranchRev);
        UKObjectsNotEqual(initialBranchRev, initialRev);
        UKObjectsNotEqual(initialRev, secondBranchRev);
        
        // Check for the proper contents
        
        UKObjectsEqual(@"1", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialBranchRev] rootObject] label]);
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialBranchRev] objectWithUUID: [childObj UUID]] label]);
        
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: secondBranchRev] rootObject] label]);
        UKObjectsEqual(@"2", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: secondBranchRev] objectWithUUID: [childObj UUID]] label]);
        
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialRev] rootObject] label]);
        UKObjectsEqual(@"0", [(OutlineItem *)[[persistentRootCtx2 objectGraphContextForPreviewingRevision: initialRev] objectWithUUID: [childObj UUID]] label]);
    }
    
    // TODO: continue
}

@end
