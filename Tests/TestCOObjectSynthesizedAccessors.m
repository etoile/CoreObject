#import "TestCommon.h"

@interface TestCOObjectSynthesizedAccessors : TestCommon <UKTest>
{
    COPersistentRoot *persistentRoot;
}
@end

@implementation TestCOObjectSynthesizedAccessors

- (id) init
{
    SUPERINIT;
    ASSIGN(persistentRoot, [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"]);
    
    return self;
}

- (void)dealloc
{
    [persistentRoot release];
    [super dealloc];
}

- (void) testAttributeGetterAndSetter
{
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

#if 0
- (void) testMutableProxy
{
    OutlineItem *item = [persistentRoot rootObject];

    OutlineItem *child1 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];

    // FIXME: Change to mutableOrderedSetValueForKey
    [[item mutableArrayValueForKey: @"children"] addObject: child1];
    UKObjectsEqual(@[child1], [item contents]);

    [[item mutableArrayValueForKey: @"children"] removeObject: child1];
    UKObjectsEqual(@[], [item contents]);
}
#endif

@end
