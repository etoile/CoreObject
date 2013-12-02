#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

/**
 * Test model object that has a univalued NSString attribute
 */
@interface UnivaluedAttributeModel : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@end

@implementation UnivaluedAttributeModel

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnivaluedAttributeModel"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
		
	[entity setPropertyDescriptions: @[labelProperty]];
	
    return entity;
}

@dynamic label;

@end

@interface TestUnivaluedAttribute : TestCase <UKTest>
{
	COObjectGraphContext *ctx;
	UnivaluedAttributeModel *item1;
}
@end

@implementation TestUnivaluedAttribute

- (id) init
{
	SUPERINIT;
	ctx = [COObjectGraphContext new];
	item1 = [ctx insertObjectWithEntityName: @"UnivaluedAttributeModel"];
	item1.label = @"test";
	[ctx setRootObject: item1];
	return self;
}

- (void) testBasic
{
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 UnivaluedAttributeModel *testItem1 = (UnivaluedAttributeModel *)testRootObject;
		 UKObjectsEqual(@"test", testItem1.label);
	 }];
}

@end
