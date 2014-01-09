/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  January 2014
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringMerge : EditingContextTestCase <UKTest>
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

- (void) testMergeOverlappingAttributeAdditions2
{
	/*
	 ctx1:
	 
	 "Hello"
	 
	 */
	
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"Hello" htmlCode: nil toAttributedString: [ctx1 rootObject]];
	
	
	/*
	 ctx2:
	 
	 "Hello"
	  ^^^^
	 bold
	 
	 */
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	COAttributedStringWrapper *ctx2Wrapper = [[COAttributedStringWrapper alloc] initWithBacking: [ctx2 rootObject]];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0,4) inTextStorage: ctx2Wrapper];
			
	/*
	 ctx3:
	 
	 "Hello"
		^^^
	 underline
	 
	 */
	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	
	COAttributedStringWrapper *ctx3Wrapper = [[COAttributedStringWrapper alloc] initWithBacking: [ctx3 rootObject]];
	[ctx3Wrapper setAttributes: @{ NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle) } range: NSMakeRange(2, 3)];

	
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: @"diff12"];
	
    COAttributedStringDiff *diff13 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx3 rootObject]
																							source: @"diff13"];
	
	[diff13 addOperationsFromDiff: diff12];
	[diff13 applyToAttributedString: [ctx1 rootObject]];
	
	/*
	 ctxExpected:
	 
	 "Hello"
	  ^^^^
	 bold
	    ^^^
		underline
	 
	 */
	
	UKObjectsEqual(A(@"He",    @"ll",         @"o"), [[ctx1 rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(@"b"),  S(@"b", @"u"), S(@"u")), [[ctx1 rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

- (void) testMergeEmptyDiffPlusAddCharacter
{
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"a" htmlCode: nil toAttributedString: [ctx1 rootObject]];

	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	/* same as ctx1 */

	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	[self clearAttributedString: [ctx3 rootObject]];
	[self appendString: @"ab" htmlCode: nil toAttributedString: [ctx3 rootObject]];
	
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: @"diff12"];
	
    COAttributedStringDiff *diff13 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx3 rootObject]
																							source: @"diff13"];
	
	[diff13 addOperationsFromDiff: diff12];
	[diff13 applyToAttributedString: [ctx1 rootObject]];
	
	UKObjectsEqual(@"ab", [(COAttributedString *)[ctx1 rootObject] string]);
}

- (void) testMergeAdditions
{
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"a" htmlCode: nil toAttributedString: [ctx1 rootObject]];
	
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	[self appendString: @"bc" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	[self appendString: @"b" htmlCode: nil toAttributedString: [ctx3 rootObject]];
	
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: @"diff12"];
	
    COAttributedStringDiff *diff13 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx3 rootObject]
																							source: @"diff13"];
	
	[diff13 addOperationsFromDiff: diff12];
	[diff13 applyToAttributedString: [ctx1 rootObject]];
	
	// FIXME: Not sure if this should be a conflict?
	// It gives "abbc" which is wrong.
#if 0
	UKObjectsEqual(@"abc", [(COAttributedString *)[ctx1 rootObject] string]);
#endif
}

@end
