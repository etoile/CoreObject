/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  January 2014
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringMerge : TestAttributedStringCommon <UKTest>
@end

@implementation TestAttributedStringMerge

- (void) testMergeOverlappingAttributeAdditions
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
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	[self clearAttributedString: [ctx2 rootObject]];
	[self appendString: @"ab" htmlCode: @"b" toAttributedString: [ctx2 rootObject]];
	[self appendString: @"c" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	
	/*
	 ctx3:
	 
	 "dabc"
	    ^^
	    italic
	 
	 */

	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	[self clearAttributedString: [ctx3 rootObject]];

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
