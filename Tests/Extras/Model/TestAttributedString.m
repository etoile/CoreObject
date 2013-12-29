/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedString : TestAttributedStringCommon <UKTest>
@end

@implementation TestAttributedString

- (void) testDiffInsertion
{
	/*
	 ctx1:
	 
	 "()"
	 
	 */
	
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"()" htmlCode: nil toAttributedString: [ctx1 rootObject]];
	
	
	/*
	 ctx2:
	 
	 "(abc)"
	    ^^
	    bold
	 
	 */
	
	COObjectGraphContext *ctx2 = [self makeAttributedString];
	[self appendString: @"(a" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	[self appendString: @"bc" htmlCode: @"b" toAttributedString: [ctx2 rootObject]];
	[self appendString: @")" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	
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
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: @"b" toAttributedString: [ctx1 rootObject]];
	[self appendString: @"def" htmlCode: @"i" toAttributedString: [ctx1 rootObject]];
	[self appendString: @"ghi" htmlCode: @"u" toAttributedString: [ctx1 rootObject]];
	
	COObjectGraphContext *ctx2 = [self makeAttributedString];
	[self appendString: @"a" htmlCode: @"b" toAttributedString: [ctx2 rootObject]];
	[self appendString: @"i" htmlCode: @"u" toAttributedString: [ctx2 rootObject]];
	
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
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"abcdefg" htmlCode: @"b" toAttributedString: [ctx1 rootObject]];
	
	COObjectGraphContext *ctx2 = [self makeAttributedString];
	[self appendString: @"ab" htmlCode: @"b" toAttributedString: [ctx2 rootObject]];
	[self appendString: @"CDE" htmlCode: @"u" toAttributedString: [ctx2 rootObject]];
	[self appendString: @"fg" htmlCode: @"b" toAttributedString: [ctx2 rootObject]];
	
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
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: nil toAttributedString: [ctx1 rootObject]];
	[self appendString: @"def" htmlCode: @"i" toAttributedString: [ctx1 rootObject]];
	[self appendString: @"ghi" htmlCode: @"u" toAttributedString: [ctx1 rootObject]];
	
	// Make 'cdefg' bold
	
	COObjectGraphContext *ctx2 = [self makeAttributedString];
	[self appendString: @"ab" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	[self appendString: @"c" htmlCode: @"b" toAttributedString: [ctx2 rootObject]];
	[self appendString: @"def" htmlCodes: @[@"b", @"i"] toAttributedString: [ctx2 rootObject]];
	[self appendString: @"g" htmlCodes: @[@"b", @"u"] toAttributedString: [ctx2 rootObject]];
	[self appendString: @"hi" htmlCode: @"u" toAttributedString: [ctx2 rootObject]];
	
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
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: @"b" toAttributedString: [ctx1 rootObject]];
	
	COObjectGraphContext *ctx2 = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: nil];
	
	UKIntsEqual(1, [diff12.operations count]);
	COAttributedStringDiffOperationRemoveAttribute *op = diff12.operations[0];
	UKObjectKindOf(op, COAttributedStringDiffOperationRemoveAttribute);
	UKIntsEqual(0, op.range.location);
	UKIntsEqual(3, op.range.length);
}

- (void) testMerge
{
	/*
	 ctx1:
	 
	 "abc"
	 	 
	 */
	
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: nil toAttributedString: [ctx1 rootObject]];

	
	/*
	 ctx2:
	 
	 "abc"
	  ^^
	  bold
	 
	 */
	
	COObjectGraphContext *ctx2 = [self makeAttributedString];
	[self appendString: @"ab" htmlCode: @"b" toAttributedString: [ctx2 rootObject]];
	[self appendString: @"c" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	
	/*
	 ctx3:
	 
	 "dabc"
	    ^^
	    italic
	 
	 */

	
	COObjectGraphContext *ctx3 = [self makeAttributedString];
	[self appendString: @"da" htmlCode: nil toAttributedString: [ctx3 rootObject]];
	[self appendString: @"bc" htmlCode: @"i" toAttributedString: [ctx3 rootObject]];
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: @"diff12"];
	
    COAttributedStringDiff *diff13 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx3 rootObject]
																							source: @"diff13"];
	
	[diff12 addOperationsFromDiff: diff13];
	[diff12 applyToAttributedString: [ctx1 rootObject]];
	
	/*
	 ctxExpected:
	 
	 "dabc"
	   ^^
	   bold
	    ^^
		italic
	   	
	 */
	
	UKObjectsEqual(A(@"d", @"a",    @"b",          @"c"), [[ctx1 rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(),  S(@"b"), S(@"b", @"i"), S(@"i")), [[ctx1 rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

@end
