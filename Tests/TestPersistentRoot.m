#import "TestCommon.h"
#import <UnitKit/UnitKit.h>
#import <CoreObject/COPersistentRoot.h>
#import "COItem.h"

@interface TestPersistentRoot : TestCommon <UKTest>
@end

@implementation TestPersistentRoot

- (void) testItemGraphProtocol
{
    COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    COObject *rootObj = [proot rootObject];
    UKObjectsEqual(S([rootObj UUID]), SA([proot itemUUIDs]));
    
    COItem *rootItem = [proot itemForUUID: [rootObj UUID]];
    UKObjectsEqual([rootObj UUID], [rootItem UUID]);
    
    COMutableItem *rootItemCopy = [rootItem mutableCopy];
    [rootItemCopy setValue: @"test item" forAttribute: @"label"];

    UKNil([rootObj valueForKey: @"label"]);
    [proot addItem: rootItemCopy];
    UKObjectsEqual(@"test item", [rootObj valueForKey: @"label"]);
}

@end
