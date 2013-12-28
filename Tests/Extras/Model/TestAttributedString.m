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

	[op applyOperationToAttributedString: [ctx1 rootObject] withOffset: 0];
	
	// NOTE: It would also be valid if the first two characters '(' and 'a' were joined.
	
	UKObjectsEqual(A(@"(", @"a", @"bc", @")"), [[ctx1 rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(), S(), S(@"b"), S()), [[ctx1 rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
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
	
//	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
//	
//	COObjectGraphContext *ctxMerged = [COObjectGraphContext new];
//	[ctxMerged setItemGraph: ctx1];
//	[merged applyTo: ctxMerged];
	
	/*
	 ctxExpected:
	 
	 "dabc"
	   ^^
	   bold
	    ^^
		italic
	   
	 Note that the merge process will introduce new objects when it splits chunks, so we can't
	 just build the expected object graph ahead of time but have to do the merge and inspect
	 the result.
	 
	 */
	
	UKPass();
}

@end
