#import "TestCommon.h"

@interface TestCOObjectSynthesizedAccessors : TestCommon <UKTest>
@end

@implementation TestCOObjectSynthesizedAccessors

- (void) testBasic
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    
    OutlineItem *item = [persistentRoot rootObject];
    UKObjectKindOf(item, OutlineItem);
    
    [item setLabel: @"hello"];
    UKObjectsEqual(@"hello", [item label]);
    
    OutlineItem *child1 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [child1 setLabel: @"child1"];

    OutlineItem *child2 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [child2 setLabel: @"child2"];

    [item setContents: A(child1, child2)];
    UKObjectsEqual(A(child1, child2), [item contents]);
}

@end
