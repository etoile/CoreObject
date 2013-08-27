#import "TestCommon.h"

@interface TestCOObjectSynthesizedAccessors : TestCommon <UKTest>
@end

@implementation TestCOObjectSynthesizedAccessors

- (void) testBasic
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    
    OutlineItem *item = [persistentRoot rootObject];
    UKObjectKindOf(item, OutlineItem);
}

@end
