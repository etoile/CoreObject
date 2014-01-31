/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringDiff : EditingContextTestCase <UKTest>
@end

@implementation TestAttributedStringDiff

- (void) testDiffInsertion
{
	COObjectGraphContext *ctx1 = [self makeAttributedStringWithHTML: @"()"];
	COObjectGraphContext *ctx2 = [self makeAttributedStringWithHTML: @"(a<B>bc</B>)"];

	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: nil];
	
	UKIntsEqual(1, [diff12.operations count]);
	COAttributedStringDiffOperationInsertAttributedSubstring *op = diff12.operations[0];
	UKObjectKindOf(op, COAttributedStringDiffOperationInsertAttributedSubstring);
	UKIntsEqual(1, op.range.location);

	COObjectGraphContext *insertedStringCtx = [COObjectGraphContext new];
	[insertedStringCtx setItemGraph: op.attributedStringItemGraph];
	UKObjectsEqual(A(@"a", @"bc"), [[insertedStringCtx rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(),  S(@"b")), [[insertedStringCtx rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

- (void) testDiffDeletion
{
	COObjectGraphContext *ctx1 = [self makeAttributedStringWithHTML: @"<B>abc</B><I>def</I><U>ghi</U>"];
	COObjectGraphContext *ctx2 = [self makeAttributedStringWithHTML: @"<B>a</B><U>i</U>"];
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: nil];
	
	UKIntsEqual(1, [diff12.operations count]);
	COAttributedStringDiffOperationDeleteRange *op = diff12.operations[0];
	UKObjectKindOf(op, COAttributedStringDiffOperationDeleteRange);
	UKIntsEqual(1, op.range.location);
	UKIntsEqual(7, op.range.length);
}

- (void) testDiffReplacement
{
	COObjectGraphContext *ctx1 = [self makeAttributedStringWithHTML: @"<B>abcdefg</B>"];
	COObjectGraphContext *ctx2 = [self makeAttributedStringWithHTML: @"<B>ab</B><U>CDE</U><B>fg</B>"];

	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: nil];
	
	UKIntsEqual(1, [diff12.operations count]);
	COAttributedStringDiffOperationReplaceRange *op = diff12.operations[0];
	UKObjectKindOf(op, COAttributedStringDiffOperationReplaceRange);
	UKIntsEqual(2, op.range.location);
	UKIntsEqual(3, op.range.length);
	
	COObjectGraphContext *insertedStringCtx = [COObjectGraphContext new];
	[insertedStringCtx setItemGraph: op.attributedStringItemGraph];
	UKObjectsEqual(A(@"CDE"), [[insertedStringCtx rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(@"u")), [[insertedStringCtx rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

- (void) testDiffAddAttribute
{
	COObjectGraphContext *ctx1 = [self makeAttributedStringWithHTML: @"abc<I>def</I><U>ghi</U>"];
	// Make 'cdefg' bold
	COObjectGraphContext *ctx2 = [self makeAttributedStringWithHTML: @"ab<B>c<I>def</I><U>g</B>hi</U>"];
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: nil];
	
	UKIntsEqual(1, [diff12.operations count]);
	COAttributedStringDiffOperationAddAttribute *op = diff12.operations[0];
	UKObjectKindOf(op, COAttributedStringDiffOperationAddAttribute);
	UKIntsEqual(2, op.range.location);
	UKIntsEqual(5, op.range.length);
	
	COObjectGraphContext *insertedAttributeCtx = [COObjectGraphContext new];
	[insertedAttributeCtx setItemGraph: op.attributeItemGraph];
	UKObjectsEqual(@"b", [[insertedAttributeCtx rootObject] htmlCode]);
}

- (void) testDiffRemoveAttribute
{
	COObjectGraphContext *ctx1 = [self makeAttributedStringWithHTML: @"<B>abc</B>"];
	COObjectGraphContext *ctx2 = [self makeAttributedStringWithHTML: @"abc"];
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: nil];
	
	UKIntsEqual(1, [diff12.operations count]);
	COAttributedStringDiffOperationRemoveAttribute *op = diff12.operations[0];
	UKObjectKindOf(op, COAttributedStringDiffOperationRemoveAttribute);
	UKIntsEqual(0, op.range.location);
	UKIntsEqual(3, op.range.length);
}

- (void) testApplyDiffWithRemoveRangeAndRemoveAttributes
{
	COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"Hello <B>World</B>"];

	COAttributedStringDiffOperationDeleteRange *op1 = [[COAttributedStringDiffOperationDeleteRange alloc] init];
	op1.attributedStringUUID = [[target rootObject] UUID];
	op1.range = NSMakeRange(0, 6);
	op1.source = @"diff2";
	
	COAttributedStringDiffOperationDeleteRange *op2 = [[COAttributedStringDiffOperationDeleteRange alloc] init];
	op2.attributedStringUUID = [[target rootObject] UUID];
	op2.range = NSMakeRange(6, 5);
	op2.source = @"diff1";
	
	COObjectGraphContext *boldGraph = [COObjectGraphContext new];
	[boldGraph setRootObject: [self makeAttr: @"b" inCtx: boldGraph]];
	
	COAttributedStringDiffOperationRemoveAttribute *op3 = [[COAttributedStringDiffOperationRemoveAttribute alloc] init];
	op3.attributedStringUUID = [[target rootObject] UUID];
	op3.attributeItemGraph = [[COItemGraph alloc] initWithItemGraph: boldGraph];
	op3.range = NSMakeRange(6, 5);
	op3.source = @"diff2";
	
	COAttributedStringDiff *diff = [[COAttributedStringDiff alloc] initWithOperations: @[op1, op2, op3]];
	
	// FIXME: -addedOrUpdatedItemsForApplyingTo: raises exception
#if 0
	NSDictionary *diffOutput = [diff addedOrUpdatedItemsForApplyingTo: target];
	[target insertOrUpdateItems: [diffOutput allValues]];
	
	UKObjectsEqual(@"", [[target rootObject] string]);
#endif
}

@end
