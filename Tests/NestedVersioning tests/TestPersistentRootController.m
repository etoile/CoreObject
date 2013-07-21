#import "TestCommon.h"


@interface TestPersistentRootController : COSQLiteStoreTestCase <UKTest> {
}

@end


@implementation TestPersistentRootController

- (id<COItemGraph>) initialContents
{
    COObjectGraphContext *ctx = [COObjectGraphContext editingContext];
    COObject *obj = [ctx insertObject];
    [obj setValue: @"root" forAttribute: @"label" type: kCOStringType];
    [ctx setRootObject: obj];
    return ctx;
}

- (void) testBasic
{
    COPersistentRootInfo *proot = [store createPersistentRootWithInitialContents: [self initialContents]
                                                                         metadata: [NSDictionary dictionary]];
    
    // Verify that the new persistent root is saved
    UKIntsEqual(1, [[store persistentRootUUIDs] count]);

    COPersistentRootController *controller = [[[COPersistentRootController alloc] initWithStore: store
                                                                             persistentRootUUID: [proot UUID]] autorelease];
    

    COObject *root = [[controller editingContext] rootObject];
    [root setValue: @"name2" forAttribute: @"label"];
    
    UKObjectsEqual(S([root UUID]), [[controller editingContext] modifiedObjectUUIDs]);
    
    UKTrue([controller commitChangesWithMetadata: nil]);
    
    CORevisionID *newRev = [[[store persistentRootWithUUID: [controller UUID]] currentBranchInfo] currentRevisionID];
    
    UKObjectsNotEqual([[proot currentBranchInfo] currentRevisionID], newRev);
    
//    
//    
//    // Create a new branch and switch to it.
//    
//    COBranch *newBranch = [proot createBranchAtRevision: [[proot currentBranch] currentRevisionID]
//                                             setCurrent: YES];
//    COUUID *newBranchUUID = [newBranch UUID];
//    
//    UKIntsEqual(2, [[proot branches] count]);
//    
//    UKObjectsEqual(@"root", [[[newBranch editingContext] rootObject] valueForAttribute: @"label"]);
//    UKFalse([newBranch hasChanges]);
//    
//    // Commit a change to the new branch.
//    
//    [[[newBranch editingContext] rootObject] addObjectToContents: makeTree(@"pizza")];
//    UKTrue([newBranch hasChanges]);
//    
//    [newBranch commitChangesWithMetadata: [NSDictionary dictionary]];
//    UKFalse([newBranch hasChanges]);
//    CORevisionID *secondRevision = [newBranch currentRevisionID];
//    COItemTree *secondTree = [[newBranch editingContext] itemTree];
//    
//    UKObjectsNotEqual(firstRevision, secondRevision);
//    UKObjectsNotEqual(firstState, secondTree);
//    
//    // Check that the currentBranch context is updated
//    // if we switch branch
//    
//    UKObjectsEqual(newBranchUUID, [currentBranch UUID]);
//
//
//    // Delete the first branch
//    [proot removeBranch: firstBranch];
//    UKIntsEqual(1, [[proot branches] count]);
}

@end
