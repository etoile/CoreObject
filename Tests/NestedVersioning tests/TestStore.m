#import "TestCommon.h"

#define STOREPATH [@"~/om6teststore" stringByExpandingTildeInPath]
#define STOREURL [NSURL fileURLWithPath: STOREPATH]

@interface TestStore : NSObject <UKTest> {
	COSQLiteStore *store;
}

@end


@implementation TestStore

- (id) init
{
    self = [super init];
    
    [[NSFileManager defaultManager] removeItemAtPath: STOREPATH error: NULL];
    store = [[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: STOREPATH]];
    return self;
}

- (void) dealloc
{
    [[NSFileManager defaultManager] removeItemAtPath: STOREPATH error: NULL];
    [store release];
    [super dealloc];
}

- (void) testTokenInMemory
{
    COUUID *aUUID = [COUUID UUID];
    
    CORevisionID *t = [[CORevisionID alloc] initWithPersistentRootBackingStoreUUID: aUUID revisionIndex: 1];
    
    UKObjectsEqual(t, [CORevisionID revisionIDWithPlist: [t plist]]);    
}

static COObject *makeTree(NSString *label)
{
    COEditingContext *ctx = [[[COEditingContext alloc] init] autorelease];
    [[ctx rootObject] setValue: label
                  forAttribute: @"label"
                          type: kCOStringType];
    return [ctx rootObject];
}

- (CORevisionID *) currentState: (COPersistentRootState *)aRoot
{
    return [[aRoot branchPlistForUUID: [aRoot currentBranchUUID]] currentState];
}

- (void) testBasic
{
	COItemTree *basicTree = [makeTree(@"hello world") itemTree];
    
    COPersistentRootState *proot = [store createPersistentRootWithInitialContents: basicTree
                                                                         metadata: [NSDictionary dictionary]];
    
    UKObjectsEqual(S([proot UUID]), [NSSet setWithArray: [store persistentRootUUIDs]]);
    
    COItemTree *fetchedTree = [store itemTreeForRevisionID: [self currentState: proot]];
    UKObjectsEqual(basicTree, fetchedTree);
    
    COPersistentRootState *prootFetchedFirst = [store persistentRootWithUUID: [proot UUID]];
    UKObjectsEqual(proot, prootFetchedFirst);
    
    // make a second commit
    
    COMutableItem *modifiedItem = [[[basicTree itemForUUID: [basicTree rootItemUUID]] mutableCopy] autorelease];
    [modifiedItem setValue: @"hello world 2" forAttribute: @"label" type: kCOStringType];
    COItemTree *basicTree2 = [COItemTree itemTreeWithItems: A(modifiedItem) rootItemUUID: [modifiedItem UUID]];
    
    CORevisionID *token2 = [store writeItemTree: basicTree2
                                   withMetadata: nil
                           withParentRevisionID: [[proot branchPlistForUUID: [proot currentBranchUUID]] currentState]
                                  modifiedItems: nil];
    
    [store setCurrentVersion: token2
                   forBranch: [proot currentBranchUUID]
            ofPersistentRoot: [proot UUID]];
    
    COPersistentRootState *prootFetched = [store persistentRootWithUUID: [proot UUID]];
    CORevisionID *currentState = [self currentState: prootFetched];
    UKNotNil(currentState);
    
    fetchedTree = [store itemTreeForRevisionID: currentState];
    UKObjectsEqual(basicTree2, fetchedTree);
}

- (void) testReferenceType
{
    {
        COEditingContext *ctx = [COEditingContext editingContext];
        [[ctx rootObject] setValue: @"Photo groups"
                      forAttribute: @"label"
                              type: kCOStringType];
        
        //             /- friends---\
        // photo groups              photo1
        //             \- vacations-/
    }

}

//
//- (void) testWithEditingContext
//{
//	COStore *store = setupStore();
//	COSubtree *basicTree = makeTree(@"hello world");
//    
//    // FIXME: Move support for this to editing context
//    
//    COPersistentRootState *state = [COPersistentRootState stateWithTree: basicTree];
//    COPersistentRoot *proot = [store createPersistentRootWithInitialContents: state];
//    
//    COPersistentRootEditingContext *ctx = [COPersistentRootEditingContext contextForEditingPersistentRootWithUUID: [proot UUID]
//                                                                                                          inStore: store];
//
//    UKObjectsEqual(basicTree, [ctx persistentRootTree]);
//    
//    // make a second commit
//    
//    [[ctx persistentRootTree] setValue: @"changed with context" forAttribute: @"name" type: kCOStringType];
//
//    [ctx commitWithMetadata: nil];
//    
//    UKObjectsEqual(@"changed with context", [[[store fullStateForPersistentRootWithUUID: [ctx UUID]] tree] valueForAttribute: @"name"]);
//}

//- (void)testReopenStore
//{
//	COUUID *prootUUID = nil;
//    
//    COPersistentRootState *state = [COPersistentRootState stateWithTree: makeTree(@"hello world")];
//    
//	{
//        COStore *s = [[COStore alloc] initWithURL: STOREURL];
//        
//        prootUUID = [COUUID UUID];
//        [s createPersistentRootWithUUID: prootUUID
//                            initialContents: state];
//        id<COPersistentRoot> proot = [s persistentRootWithUUID: prootUUID];
//        [s release];
//    }
//    
//    {
//        COStore *s = [[COStore alloc] initWithURL: STOREURL];
//        id<COPersistentRoot> prootFetched = [s persistentRootWithUUID: prootUUID];
//        UKObjectsEqual(state, [s fullStateForToken: [self currentState: prootFetched]]);
//        [s release];
//    }
//	
//	[[NSFileManager defaultManager] removeItemAtPath: STOREPATH error: NULL];
//}
//
//- (void)testDeletePersistentRoot
//{
//	COStore *store = setupStore();
//	COSubtree *basicTree = makeTree(@"hello world");
//    
//    COPersistentRootState *state = [COPersistentRootState stateWithTree: basicTree];
//    
//    COUUID *uuid = [COUUID UUID];
//    [store createPersistentRootWithUUID: uuid
//                        initialContents: state];
//    id<COPersistentRoot> proot = [store persistentRootWithUUID: uuid];
//    
//    UKObjectsEqual(S(uuid), [store allPersistentRootUUIDs]);
//    
//    [store deletePersistentRoot: uuid];
//    
//    UKObjectsEqual([NSSet set], [store allPersistentRootUUIDs]);
//}

//- (void)testBranch
//{
//	// create a persistent root r with 3 branches: a, b, c; current branch: a
//	
//    COStore *store = setupStore();
//    // N.B. these commit immediately.
//    COPersistentRootState *state = [COPersistentRootState stateWithTree: makeTree(@"hello world")];
//    COPersistentRootState *state2 = [COPersistentRootState stateWithTree: makeTree(@"hello world2")];
//    COPersistentRootState *state3 = [COPersistentRootState stateWithTree: makeTree(@"hello world3")];
//    
//    COPersistentRoot *proot = [store createPersistentRootWithInitialContents: state];
//    COUUID *prootuuid = [proot UUID];
//    COPersistentRootStateToken *token = [self currentState: proot];
//    COPersistentRootStateToken *token2 = [store addState: state2 parentState: token];
//    COPersistentRootStateToken *token3 = [store addState: state3 parentState: token];
//    
//    COBranch *branch = [proot currentBranch];
//    COUUID *branch2uuid = [store createCopyOfBranch: [branch UUID] ofPersistentRoot: prootuuid];    
//    COUUID *branch3uuid = [store createCopyOfBranch: [branch UUID] ofPersistentRoot: prootuuid];
//
//    proot = [store persistentRootWithUUID: prootuuid];
//    COBranch *branch2 = [proot branchForUUID: branch2uuid];
//    COBranch *branch3 = [proot branchForUUID: branch3uuid];
//    
//    UKObjectsEqual(branch2uuid, [branch2 UUID]);
//    UKObjectsEqual(branch3uuid, [branch3 UUID]);
//    
//    UKObjectsEqual(S(branch, branch2, branch3), [NSSet setWithArray: [[store persistentRootWithUUID: prootuuid] branches]]);
//    
//    [store setCurrentBranch: branch2uuid forPersistentRoot: prootuuid];
//    
//    UKObjectsEqual(branch2uuid, [[[store persistentRootWithUUID: prootuuid] currentBranch] UUID]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid]);
//    
//    [store setCurrentVersion: token2 forBranch: branch2uuid ofPersistentRoot: prootuuid];
//    
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: prootuuid]);
//    
//    [store setCurrentVersion: token3 forBranch: branch3uuid ofPersistentRoot: prootuuid];
//    
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: prootuuid]);
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch2uuid]);
//    UKObjectsEqual(state3, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch3uuid]);
//
//    // =========
//    // test undo
//    // =========
//    
//    UKFalse([store canRedoForPersistentRootWithUUID: prootuuid]);
//    
//    [store undoForPersistentRootWithUUID: prootuuid]; // undo branch3 (state -> state3)
//    
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: prootuuid]);
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch2uuid]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch3uuid]);
//    
//    [store undoForPersistentRootWithUUID: prootuuid]; // undo branch2 (state -> state2)
//    
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch2uuid]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch3uuid]);
//    
//    [store undoForPersistentRootWithUUID: prootuuid]; // undo switch current branch (branch -> branch2)
//    
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid]);
//    UKObjectsEqual([branch UUID], [[[store persistentRootWithUUID: prootuuid] currentBranch] UUID]);
//    
//    [store undoForPersistentRootWithUUID: prootuuid]; // undo creation of branch3
//    
//    UKIntsEqual(2, [[[store persistentRootWithUUID: prootuuid] branches] count]);
//    
//    [store undoForPersistentRootWithUUID: prootuuid]; // undo creation of branch2
//    
//    UKObjectsEqual(S(branch), [NSSet setWithArray: [[store persistentRootWithUUID: prootuuid] branches]]);
//    
//    UKFalse([store canUndoForPersistentRootWithUUID: prootuuid]);
//    
//    // =========
//    // test redo
//    // =========
//    
//    [store redoForPersistentRootWithUUID: prootuuid]; // redo creation of branch2
//    
//    UKIntsEqual(2, [[[store persistentRootWithUUID: prootuuid] branches] count]);
//    
//    [store redoForPersistentRootWithUUID: prootuuid]; // redo creation of branch3
//
//    UKIntsEqual(3, [[[store persistentRootWithUUID: prootuuid] branches] count]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch2uuid]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch3uuid]);
//
//    [store redoForPersistentRootWithUUID: prootuuid]; // redo switch current branch (branch -> branch2)  
//    
//    UKObjectsEqual(branch2uuid, [[[store persistentRootWithUUID: prootuuid] currentBranch] UUID]);
//    
//    [store redoForPersistentRootWithUUID: prootuuid]; // redo branch2 (state -> state2)
//    
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch2uuid]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch3uuid]);
//    
//    [store redoForPersistentRootWithUUID: prootuuid]; // redo branch3 (state -> state3)
//    
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch2uuid]);
//    UKObjectsEqual(state3, [store fullStateForPersistentRootWithUUID: prootuuid branchUUID: branch3uuid]);
//    UKFalse([store canRedoForPersistentRootWithUUID: prootuuid]);
//}

//- (void)testCopyPersistentRoot
//{
//	COStore *store = setupStore();
//
//    COPersistentRootState *state = [COPersistentRootState stateWithTree: makeTree(@"hello world")];
//    COPersistentRootState *state2 = [COPersistentRootState stateWithTree: makeTree(@"hello world2")];
//    UKObjectsNotEqual(state, state2);
//    
//    COPersistentRoot *proot = [store createPersistentRootWithInitialContents: state];
//    COPersistentRoot *proot2 = [store createCopyOfPersistentRoot: [proot UUID]];
//    
//    UKObjectsNotEqual([proot UUID], [proot2 UUID]);
//    
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: [proot UUID]]);
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: [proot2 UUID]]);
//    
//    // change proot2, verify that it didn't change proot
//    
//    COPersistentRootStateToken *token = [[proot currentBranch] currentState];
//    COPersistentRootStateToken *token2 = [store addState: state2 parentState: token];
//    
//    [store setCurrentVersion: token2 forBranch: [[proot2 currentBranch] UUID] ofPersistentRoot: [proot2 UUID]];
//    
//    UKObjectsEqual(state, [store fullStateForPersistentRootWithUUID: [proot UUID]]);
//    UKObjectsEqual(state2, [store fullStateForPersistentRootWithUUID: [proot2 UUID]]);
//}

@end
