#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

/**
 * Test model object that has an unordered multivalued NSString attribute
 */
@interface UnorderedAttributeModel : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *contents;
@end

@implementation UnorderedAttributeModel

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"UnorderedAttributeModel"];
    [entity setParent: (id)@"Anonymous.COObject"];
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																					type: (id)@"Anonymous.NSString"];
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];
	
	[entity setPropertyDescriptions: @[labelProperty, contentsProperty]];
	
    return entity;
}

@dynamic label;
@dynamic contents;

@end

@interface TestUnorderedAttribute : TestCase <UKTest>
{
	COObjectGraphContext *ctx;
	UnorderedAttributeModel *group1;
}
@end

@implementation TestUnorderedAttribute

- (id) init
{
	SUPERINIT;
	ctx = [COObjectGraphContext new];
	group1 = [ctx insertObjectWithEntityName: @"UnorderedAttributeModel"];
	group1.contents = S(@"hello", @"world");
	[ctx setRootObject: group1];
	return self;
}

- (void) testUnorderedAttribute
{
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 UnorderedAttributeModel *testGroup1 = (UnorderedAttributeModel *)testRootObject;
		 UKObjectsEqual(S(@"hello", @"world"), testGroup1.contents);
	 }];
}

#if 0
- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedAttributeModel *group1 = [ctx insertObjectWithEntityName: @"UnorderedAttributeModel"];
	group1.contents = @[@"hello", @"hello", @"world"];
	
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 UnorderedAttributeModel *testGroup1 = (UnorderedAttributeModel *)testRootObject;
		 UKRaisesException([(NSMutableArray *)testGroup1.contents removeObjectAtIndex: 1]);
	 }];
}
#endif

@end
