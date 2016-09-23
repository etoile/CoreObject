/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"
#import "COPrimitiveCollection.h"

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
	ctx.rootObject = group1;
	return self;
}

- (void) testOrderedAttribute
{
	group1.contents = @[@"hello", @"hello", @"world"];
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
		{
			OrderedAttributeModel *testGroup1 = (OrderedAttributeModel *)testRootObject;
			UKObjectsEqual((@[@"hello", @"hello", @"world"]), testGroup1.contents);
		}];
}

- (void) testIllegalDirectModificationOfCollection
{
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 OrderedAttributeModel *testGroup1 = (OrderedAttributeModel *)testRootObject;
		 UKObjectsEqual(@[], testGroup1.contents);
		 UKRaisesException([(NSMutableArray *)testGroup1.contents addObject: @"illegal"]);
	 }];
	
	group1.contents = @[@"hello"];
	
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 OrderedAttributeModel *testGroup1 = (OrderedAttributeModel *)testRootObject;
		 UKObjectsEqual(A(@"hello"), testGroup1.contents);
		 UKRaisesException([(NSMutableArray *)testGroup1.contents addObject: @"illegal"]);
	 }];
}

// TODO: This is ugly, but it's usefult to check for now.
- (void) testCollectionHasCorrectClass
{
	UKObjectKindOf(group1.contents, COMutableArray);
	UKFalse([group1.contents isKindOfClass: [COUnsafeRetainedMutableArray class]]);
	
	group1.contents = @[@"hello"];
	UKObjectKindOf(group1.contents, COMutableArray);
	UKFalse([group1.contents isKindOfClass: [COUnsafeRetainedMutableArray class]]);
}

- (void) testCollectionHasStrongReferenceToContents
{
	@autoreleasepool
	{
		group1.contents = @[[@"hello" mutableCopy]];
		UKObjectsEqual(A(@"hello"), group1.contents);
	}
	
	// N.B.: If the implementation is not keeping strong refs as it should, this should
	// cause a dangling pointer dereference so may produce weird results or crash instead
	// of just failing.
	UKObjectsEqual(A(@"hello"), group1.contents);
}

- (void)testNullDisallowedInCollection
{
	UKRaisesException([group1 setContents: @[[NSNull null]]]);
}

@end
