/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"
#import "COPrimitiveCollection.h"





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
	ctx.rootObject = group1;
	return self;
}

- (void) testUnorderedAttribute
{
	group1.contents = S(@"hello", @"world");
	
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 UnorderedAttributeModel *testGroup1 = (UnorderedAttributeModel *)testRootObject;
		 UKObjectsEqual(S(@"hello", @"world"), testGroup1.contents);
	 }];
}

- (void) testIllegalDirectModificationOfCollection
{
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 UnorderedAttributeModel *testGroup1 = (UnorderedAttributeModel *)testRootObject;
		 UKObjectsEqual([NSSet set], testGroup1.contents);
		 UKRaisesException([(NSMutableSet *)testGroup1.contents addObject: @"illegal"]);
	 }];
	
	group1.contents = S(@"hello");
	
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 UnorderedAttributeModel *testGroup1 = (UnorderedAttributeModel *)testRootObject;
		 UKObjectsEqual(S(@"hello"), testGroup1.contents);
		 UKRaisesException([(NSMutableSet *)testGroup1.contents addObject: @"illegal"]);
	 }];
}

// TODO: This is ugly, but it's usefult to check for now.
- (void) testCollectionHasCorrectClass
{
	UKObjectKindOf(group1.contents, COMutableSet);
	UKFalse([group1.contents isKindOfClass: [COUnsafeRetainedMutableSet class]]);

	group1.contents = S(@"hello");
	UKObjectKindOf(group1.contents, COMutableSet);
	UKFalse([group1.contents isKindOfClass: [COUnsafeRetainedMutableSet class]]);
}

- (void) testCollectionHasStrongReferenceToContents
{
	@autoreleasepool
	{
		group1.contents = S([@"hello" mutableCopy]);
		UKObjectsEqual(S(@"hello"), group1.contents);
	}
				
	// N.B.: If the implementation is not keeping strong refs as it should, this should
	// cause a dangling pointer dereference so may produce weird results or crash instead
	// of just failing.
	UKObjectsEqual(S(@"hello"), group1.contents);
}

- (void)testNullDisallowedInCollection
{
	UKRaisesException([group1 setContents: S([NSNull null])]);
}

@end
