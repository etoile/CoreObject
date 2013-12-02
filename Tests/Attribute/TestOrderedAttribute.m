#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

/**
 * Test model object that has an ordered multivalued NSString attribute
 */
@interface OrderedAttributeModel : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;
@end

@implementation OrderedAttributeModel

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"OrderedAttributeModel"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.NSString"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: YES];
	
	[entity setPropertyDescriptions: @[labelProperty, contentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;

@end

@interface TestOrderedAttribute : TestCase <UKTest>
{
	COObjectGraphContext *ctx;
	OrderedAttributeModel *group1;
}
@end

@implementation TestOrderedAttribute

- (id) init
{
	SUPERINIT;
	ctx = [COObjectGraphContext new];
	group1 = [ctx insertObjectWithEntityName: @"OrderedAttributeModel"];
	group1.contents = @[@"hello", @"hello", @"world"];
	[ctx setRootObject: group1];
	return self;
}

- (void) testOrderedAttribute
{
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
		{
			OrderedAttributeModel *testGroup1 = (OrderedAttributeModel *)testRootObject;
			UKObjectsEqual((@[@"hello", @"hello", @"world"]), testGroup1.contents);
		}];
}

#if 0
- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	OrderedAttributeModel *group1 = [ctx insertObjectWithEntityName: @"OrderedAttributeModel"];
	group1.contents = @[@"hello", @"hello", @"world"];
	
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 OrderedAttributeModel *testGroup1 = (OrderedAttributeModel *)testRootObject;
		 UKRaisesException([(NSMutableArray *)testGroup1.contents removeObjectAtIndex: 1]);
	 }];
}
#endif

@end
