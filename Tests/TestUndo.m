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
    
    // FIXME: Hack
    [[NSFileManager defaultManager] removeItemAtPath: [@"~/coreobject-undo.sqlite" stringByExpandingTildeInPath] error: NULL];
    
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

@end
