/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  January 2014
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringMerge : EditingContextTestCase <UKTest>
@end

@implementation TestAttributedStringMerge

- (void) appendHTMLString: (NSString *)html toAttributedString: (COAttributedString *)dest
{
	NSUInteger len = [html length];
	
	NSMutableSet *attributes = [NSMutableSet new];
	BOOL inAngleBrackets = NO;
	BOOL isRemoving = NO;
	NSString *htmlCode = @"";
	
	for (NSUInteger i = 0; i < len; i++)
	{
		NSString *character = [html substringWithRange: NSMakeRange(i, 1)];
		if (inAngleBrackets)
		{
			if ([character isEqualToString: @"\\"])
			{
				isRemoving = YES;
			}
			else if ([character isEqualToString: @">"])
			{
				htmlCode = [htmlCode lowercaseString];
				if (isRemoving)
				{
					[attributes removeObject: htmlCode];
				}
				else
				{
					[attributes addObject: htmlCode];
				}
				
				inAngleBrackets = NO;
				isRemoving = NO;
				htmlCode = @"";
			}
			else
			{
				htmlCode = [htmlCode stringByAppendingString: character];
			}
		}
		else
		{
			if ([character isEqualToString: @"<"])
			{
				inAngleBrackets = YES;
			}
			else
			{
				[self appendString: character htmlCodes: [attributes allObjects] toAttributedString: dest];
			}
		}
	}
}

- (void) checkMergingBase: (NSString *)base
			  withBranchA: (NSString *)branchA
			  withBranchB: (NSString *)branchB
					gives: (NSString *)result
{
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendHTMLString: base toAttributedString: [ctx1 rootObject]];

	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	[self clearAttributedString: [ctx2 rootObject]];
	[self appendHTMLString: branchA toAttributedString: [ctx2 rootObject]];
	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	[self clearAttributedString: [ctx3 rootObject]];
	[self appendHTMLString: branchB toAttributedString: [ctx3 rootObject]];
	
	COAttributedStringDiff *diffA = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: @"branchA"];
	
    COAttributedStringDiff *diffB = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx3 rootObject]
																							source: @"branchB"];
	
	COAttributedStringDiff *diffMerged = [diffA diffByMergingWithDiff: diffB];
	
	COObjectGraphContext *destCtx = [COObjectGraphContext new];
	[destCtx setItemGraph: ctx1];

	[diffMerged applyToAttributedString: [destCtx rootObject]];


	COObjectGraphContext *expectedCtx = [COObjectGraphContext new];
	[expectedCtx setItemGraph: ctx1];
	[self clearAttributedString: [expectedCtx rootObject]];
	[self appendHTMLString: result toAttributedString: [expectedCtx rootObject]];
	
	
	COAttributedStringWrapper *actualWrapper = [[COAttributedStringWrapper alloc] initWithBacking: [destCtx rootObject]];
	COAttributedStringWrapper *expectedWrapper = [[COAttributedStringWrapper alloc] initWithBacking: [expectedCtx rootObject]];
	
	UKObjectsEqual(expectedWrapper, actualWrapper);
}

- (void) testMergeOverlappingAttributeAdditions
{
	[self checkMergingBase: @"abc"
			   withBranchA: @"<B>ab</B>c"
			   withBranchB: @"da<I>bc</I>"
					 gives: @"d<B>a<I>b</B>c</I>"];
}

- (void) testMergeOverlappingAttributeAdditions2
{
	[self checkMergingBase: @"hello"
			   withBranchA: @"<B>hell</B>o"
			   withBranchB: @"he<I>llo</I>"
					 gives: @"<B>he<I>ll</B>o</I>"];
}

- (void) testMergeEmptyDiffPlusAddCharacter
{
	[self checkMergingBase: @"a"
			   withBranchA: @"a"
			   withBranchB: @"ab"
					 gives: @"ab"];
}

- (void) testMergeAdditions
{
	[self checkMergingBase: @"a"
			   withBranchA: @"ab"
			   withBranchB: @"abc"
					 gives: @"abbc"];
}

- (void) testMergeConflictingInserts
{
	COObjectGraphContext *ctx1 = [self makeAttributedString];
	[self appendString: @"a" htmlCode: nil toAttributedString: [ctx1 rootObject]];
	UKObjectsEqual(@"a", [[[COAttributedStringWrapper alloc] initWithBacking: [ctx1 rootObject]] string]);
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx1];
	[self appendString: @"bc" htmlCode: nil toAttributedString: [ctx2 rootObject]];
	UKObjectsEqual(@"abc", [[[COAttributedStringWrapper alloc] initWithBacking: [ctx2 rootObject]] string]);
	
	COObjectGraphContext *ctx3 = [COObjectGraphContext new];
	[ctx3 setItemGraph: ctx1];
	[self appendString: @"def" htmlCode: nil toAttributedString: [ctx3 rootObject]];
	UKObjectsEqual(@"adef", [[[COAttributedStringWrapper alloc] initWithBacking: [ctx3 rootObject]] string]);
	
	COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx2 rootObject]
																							source: @"diff12"];
	
    COAttributedStringDiff *diff13 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: [ctx1 rootObject]
																			secondAttributedString: [ctx3 rootObject]
																							source: @"diff13"];

	{
		COAttributedStringDiff *mergeA = [diff12 diffByMergingWithDiff: diff13];
		[mergeA resolveConflictsFavoringSourceIdentifier: @"diff12"];
		COObjectGraphContext *mergeAapplied = [[COObjectGraphContext alloc] init];
		[mergeAapplied setItemGraph: ctx1];
		[mergeA applyToAttributedString: [mergeAapplied rootObject]];
		UKObjectsEqual(@"abcdef", [(COAttributedString *)[mergeAapplied rootObject] string]);
	}
	{
		COAttributedStringDiff *mergeB = [diff12 diffByMergingWithDiff: diff13];
		[mergeB resolveConflictsFavoringSourceIdentifier: @"diff13"];
		COObjectGraphContext *mergeBapplied = [[COObjectGraphContext alloc] init];
		[mergeBapplied setItemGraph: ctx1];
		[mergeB applyToAttributedString: [mergeBapplied rootObject]];
		UKObjectsEqual(@"adefbc", [(COAttributedString *)[mergeBapplied rootObject] string]);
	}
}

@end
