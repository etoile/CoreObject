#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

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

- (void)testNullAllowedForUnivalued
{
	UKDoesNotRaiseException([item1 setLabel: nil]);
}

- (void)testNullAndNSNullEquivalent
{
	item1.label = @"foo";
	UKDoesNotRaiseException(item1.label = (NSString *)[NSNull null]);
	UKNil(item1.label);
}

@end
