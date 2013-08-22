#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestUndo : TestCommon <UKTest>
{
}
@end

@implementation TestUndo

- (id) init
{
    SUPERINIT;
    
    COUndoStackStore *uss = [[COUndoStackStore alloc] init];
    for (NSString *stack in A(@"test", @"setup", @"rootEdit", @"childEdit"))
    {
        [uss clearStacksForName: stack];
    }
    [uss release];
    
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (void)testBasic
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithStackNamed: @"test"];

    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithStackNamed: @"test"];
    
    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [ctx undoForStackNamed: @"test"];
    
    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
}

- (void)testSelectiveUndo
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COObject *root = [persistentRoot rootObject];
    COObject *child = [[[persistentRoot editingBranch] objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];    
    [root insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: kCOContents];
    [ctx commitWithStackNamed: @"setup"];
    
    [root setValue: @"root" forProperty: kCOLabel];
    [ctx commitWithStackNamed: @"rootEdit"];
    
    [child setValue: @"child" forProperty: kCOLabel];
    [ctx commitWithStackNamed: @"childEdit"];
    
    UKObjectsEqual(@"root", [root valueForProperty: kCOLabel]);
    UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
    
    // This will be a selective undo
    [ctx undoForStackNamed: @"rootEdit"];
    
    UKNil([root valueForProperty: kCOLabel]);
    UKObjectsEqual(@"child", [child valueForProperty: kCOLabel]);
}

- (void) testUndoDeleteBranch
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commit];
    
    COBranch *secondBranch = [[persistentRoot currentBranch] makeBranchWithLabel: @"secondBranch"];
    
    [[persistentRoot rootObject] setValue: @"hello2" forProperty: kCOLabel];
    [ctx commit];
    
    [secondBranch setDeleted: YES];
    [ctx commitWithStackNamed: @"test"];
    
    // Load in another context
    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: [store URL]];
        COPersistentRoot *ctx2persistentRoot = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COBranch *ctx2secondBranch = [ctx2persistentRoot branchForUUID: [secondBranch UUID]];
        
        UKTrue([ctx2secondBranch isDeleted]);
        BOOL canUndo = [ctx2 canUndoForStackNamed: @"test"];
        UKTrue(canUndo);
        if (canUndo)
        {
            [ctx2 undoForStackNamed: @"test"];
        }
        UKFalse([ctx2secondBranch isDeleted]);
    }
}

@end
