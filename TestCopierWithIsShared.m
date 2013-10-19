#import "TestCommon.h"
#import "COCopier.h"

@interface TestCopierWithIsShared : NSObject <UKTest>
{
    COItemGraph *initialGraph;
    COCopier *copier;
}
@end

/**
 * See diagram in "copy semantics.pdf", pages 8, 9
 */
@implementation TestCopierWithIsShared

static ETUUID *drawing;

static ETUUID *group1;
static ETUUID *group2;

static ETUUID *shape1;
static ETUUID *shape2;
static ETUUID *shape3;
static ETUUID *shape4;

static ETUUID *style1;
static ETUUID *style2;

static NSArray *initialUUIDs;

+ (void) initialize
{
    if (self == [TestCopierWithIsShared class])
    {
        drawing = [[ETUUID alloc] init];
		
        group1 = [[ETUUID alloc] init];
        group2 = [[ETUUID alloc] init];
		
		shape1 = [[ETUUID alloc] init];
		shape2 = [[ETUUID alloc] init];
		shape3 = [[ETUUID alloc] init];
		shape4 = [[ETUUID alloc] init];
		
        style1 = [[ETUUID alloc] init];
		style2 = [[ETUUID alloc] init];
		
		initialUUIDs = @[drawing, group1, group2, shape1, shape2, shape3, shape4, style1, style2];
    }
}

- (id) init
{
    SUPERINIT;
    copier = [[COCopier alloc] init];
    
    COMutableItem *drawingItem = [COMutableItem itemWithUUID: drawing];
    [drawingItem setValue: @[group1, group2] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    
	
    COMutableItem *group1Item = [COMutableItem itemWithUUID: group1];
    [group1Item setValue: @[shape1, shape2] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    
    COMutableItem *group2Item = [COMutableItem itemWithUUID: group2];
    [group2Item setValue: @[shape3, shape4] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    
	
	COMutableItem *shape1Item = [COMutableItem itemWithUUID: shape1];
    [shape1Item setValue: @[style1] forAttribute: @"refs" type: kCOTypeArray | kCOTypeReference];
    
    COMutableItem *shape2Item = [COMutableItem itemWithUUID: shape2];
    [shape2Item setValue: @[style1] forAttribute: @"refs" type: kCOTypeArray | kCOTypeReference];
	
	COMutableItem *shape3Item = [COMutableItem itemWithUUID: shape3];
    [shape3Item setValue: @[style2] forAttribute: @"refs" type: kCOTypeArray | kCOTypeReference];
    
    COMutableItem *shape4Item = [COMutableItem itemWithUUID: shape4];
    [shape4Item setValue: @[shape3] forAttribute: @"refs" type: kCOTypeArray | kCOTypeReference];
		
    COMutableItem *style1Item = [COMutableItem itemWithUUID: style1];
	[style1Item setValue: @"style1" forAttribute: @"name" type: kCOTypeString];
	
	COMutableItem *style2Item = [COMutableItem itemWithUUID: style2];
	[style2Item setValue: @"style2" forAttribute: @"name" type: kCOTypeString];
	[style2Item setValue: @NO forAttribute: kCOObjectIsSharedProperty type: kCOTypeInt64];
    
    initialGraph = [[COItemGraph alloc] initWithItems: @[drawingItem, group1Item, group2Item, shape1Item, shape2Item, shape3Item, shape4Item, style1Item, style2Item]
										 rootItemUUID: drawing];
    return self;
}

- (void) testCopyWithinContext
{
    UKIntsEqual(9, [[initialGraph itemUUIDs] count]);
	ETUUID *drawing2 = [copier copyItemWithUUID: drawing fromGraph: initialGraph toGraph: initialGraph];
    UKIntsEqual(17, [[initialGraph itemUUIDs] count]);
    
	// Check structure ("copy semantics.pdf" page 9)
	
    COItem *drawingCopyItem = [initialGraph itemForUUID: drawing2];
	COItem *group1CopyItem = [initialGraph itemForUUID: [drawingCopyItem valueForAttribute: @"contents"][0]];
	COItem *group2CopyItem = [initialGraph itemForUUID: [drawingCopyItem valueForAttribute: @"contents"][1]];
	COItem *shape1CopyItem = [initialGraph itemForUUID: [group1CopyItem valueForAttribute: @"contents"][0]];
	COItem *shape2CopyItem = [initialGraph itemForUUID: [group1CopyItem valueForAttribute: @"contents"][1]];
	COItem *shape3CopyItem = [initialGraph itemForUUID: [group2CopyItem valueForAttribute: @"contents"][0]];
	COItem *shape4CopyItem = [initialGraph itemForUUID: [group2CopyItem valueForAttribute: @"contents"][1]];
	COItem *style2CopyItem = [initialGraph itemForUUID: [shape3CopyItem valueForAttribute: @"refs"][0]];
	
	
	UKNotNil(drawingCopyItem);
	UKFalse([initialUUIDs containsObject: [drawingCopyItem UUID]]);
			 
	UKNotNil(group1CopyItem);
	UKFalse([initialUUIDs containsObject: [group1CopyItem UUID]]);

	UKNotNil(group2CopyItem);
	UKFalse([initialUUIDs containsObject: [group2CopyItem UUID]]);

	UKNotNil(shape1CopyItem);
	UKFalse([initialUUIDs containsObject: [shape1CopyItem UUID]]);
	
	UKNotNil(shape2CopyItem);
	UKFalse([initialUUIDs containsObject: [shape2CopyItem UUID]]);
	
	UKNotNil(shape3CopyItem);
	UKFalse([initialUUIDs containsObject: [shape3CopyItem UUID]]);

	UKNotNil(shape4CopyItem);
	UKFalse([initialUUIDs containsObject: [shape4CopyItem UUID]]);
	
	// Check that the copies of shape1 and shape2 have aliases to the original style1 and style2
	UKObjectsEqual(style1, [shape1CopyItem valueForAttribute: @"refs"][0]);
	UKObjectsEqual(style1, [shape2CopyItem valueForAttribute: @"refs"][0]);
	
	// The copy of shape3 has a reference to a copy of style2
	
	UKNotNil(style2CopyItem);
	UKFalse([initialUUIDs containsObject: [style2CopyItem UUID]]);
	UKObjectsEqual(@"style2", [style2CopyItem valueForAttribute: @"name"]);
	
	// The copy of shape4 should refer to the copy of shape3, not the original
	UKObjectsEqual([shape3CopyItem UUID], [shape4CopyItem valueForAttribute: @"refs"][0]);
}

@end
