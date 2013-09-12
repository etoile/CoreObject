#import "TestCommon.h"

@interface TestCOObjectSynthesizedAccessors : EditingContextTestCase <UKTest>
{
    COPersistentRoot *persistentRoot;
}
@end

@implementation TestCOObjectSynthesizedAccessors

- (id) init
{
    SUPERINIT;
    persistentRoot =  [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    
    return self;
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

- (void) testMutableProxy
{
    OutlineItem *item = [persistentRoot rootObject];

    OutlineItem *child1 = [[persistentRoot objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    
    // At first I didn't think this would work right now, but
    // when -mutableArrayValueForKey: does its accessor search, it causes
    // +resolveInstanceMethod: to be invoked, which lets us auto-generate
    // acecssors.
    //
    // Currently we only generate -XXX and -setXXX:, but that's sufficient
    // for -mutableArrayValueForKey: to work. We will need to add support
    // for generating the indexed ones for good performance, though.
    
    // FIXME: Change to mutableOrderedSetValueForKey
    [[item mutableArrayValueForKey: @"contents"] addObject: child1];
    UKObjectsEqual(@[child1], [item contents]);

    [[item mutableArrayValueForKey: @"contents"] removeObject: child1];
    UKObjectsEqual(@[], [item contents]);
}

@end
