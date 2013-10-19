#import "TestCommon.h"
#import "COCopier.h"

@interface TestCopierWithIsSharedFalseAndMultipleReferences : NSObject <UKTest>
{
    COItemGraph *initialGraph;
    COCopier *copier;
}
@end

/**
 * See diagram in "copy semantics.pdf", pages 10
 *
 * The graph has been reduced to contain just drawing, shape2, shape3, style2
 */
@implementation TestCopierWithIsSharedFalseAndMultipleReferences

static ETUUID *drawing;

static ETUUID *shape2;
static ETUUID *shape3;

static ETUUID *style2;

static NSArray *initialUUIDs;

+ (void) initialize
{
    if (self == [TestCopierWithIsSharedFalseAndMultipleReferences class])
    {
        drawing = [[ETUUID alloc] init];

		shape2 = [[ETUUID alloc] init];
		shape3 = [[ETUUID alloc] init];
		
		style2 = [[ETUUID alloc] init];
		
		initialUUIDs = @[drawing, shape2, shape3, style2];
    }
}

- (id) init
{
    SUPERINIT;
    copier = [[COCopier alloc] init];
    
    COMutableItem *drawingItem = [COMutableItem itemWithUUID: drawing];
    [drawingItem setValue: @[shape2, shape3] forAttribute: @"contents" type: kCOTypeArray | kCOTypeCompositeReference];
    
	COMutableItem *shape2Item = [COMutableItem itemWithUUID: shape2];
    [shape2Item setValue: @[style2] forAttribute: @"refs" type: kCOTypeArray | kCOTypeReference];
	
	COMutableItem *shape3Item = [COMutableItem itemWithUUID: shape3];
    [shape3Item setValue: @[style2] forAttribute: @"refs" type: kCOTypeArray | kCOTypeReference];
    
	COMutableItem *style2Item = [COMutableItem itemWithUUID: style2];
	[style2Item setValue: @"style2" forAttribute: @"name" type: kCOTypeString];
	[style2Item setValue: @NO forAttribute: kCOObjectIsSharedProperty type: kCOTypeInt64];
    
    initialGraph = [[COItemGraph alloc] initWithItems: @[drawingItem, shape2Item, shape3Item, style2Item]
										 rootItemUUID: drawing];
    return self;
}

- (void) testCopyWithinContext
{
    UKIntsEqual(4, [[initialGraph itemUUIDs] count]);
	ETUUID *drawing2 = [copier copyItemWithUUID: drawing fromGraph: initialGraph toGraph: initialGraph];
    UKIntsEqual(8, [[initialGraph itemUUIDs] count]);
    
	// Check structure ("copy semantics.pdf" page 10)
	
    COItem *drawingCopyItem = [initialGraph itemForUUID: drawing2];
	COItem *shape2CopyItem = [initialGraph itemForUUID: [drawingCopyItem valueForAttribute: @"contents"][1]];
	COItem *shape3CopyItem = [initialGraph itemForUUID: [drawingCopyItem valueForAttribute: @"contents"][0]];

	COItem *style2CopyItemA = [initialGraph itemForUUID: [shape2CopyItem valueForAttribute: @"refs"][0]];
	COItem *style2CopyItemB = [initialGraph itemForUUID: [shape3CopyItem valueForAttribute: @"refs"][0]];
	
	UKNotNil(drawingCopyItem);
	UKFalse([initialUUIDs containsObject: [drawingCopyItem UUID]]);
			 
	UKNotNil(shape2CopyItem);
	UKFalse([initialUUIDs containsObject: [shape2CopyItem UUID]]);
	
	UKNotNil(shape3CopyItem);
	UKFalse([initialUUIDs containsObject: [shape3CopyItem UUID]]);

	UKObjectsSame(style2CopyItemA, style2CopyItemB);
	UKNotNil(style2CopyItemA);
	UKFalse([initialUUIDs containsObject: [style2CopyItemA UUID]]);
	UKObjectsEqual(@"style2", [style2CopyItemA valueForAttribute: @"name"]);
}

@end
