/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  January 2014
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringMerge : EditingContextTestCase <UKTest>
@end


@implementation TestAttributedStringMerge

- (void)testMergeOverlappingAttributeAdditions
{
    [self checkMergingBase: @"abc"
               withBranchA: @"<B>ab</B>c"
               withBranchB: @"da<I>bc</I>"
                     gives: @"d<B>a<I>b</B>c</I>"];
}

- (void)testMergeOverlappingAttributeAdditions2
{
    [self checkMergingBase: @"hello"
               withBranchA: @"<B>hell</B>o"
               withBranchB: @"he<I>llo</I>"
                     gives: @"<B>he<I>ll</B>o</I>"];
}

- (void)testMergeEmptyDiffPlusAddCharacter
{
    [self checkMergingBase: @"a"
               withBranchA: @"a"
               withBranchB: @"ab"
                     gives: @"ab"];
}

- (void)testMergeAdditions
{
    [self checkMergingBase: @"a"
               withBranchA: @"ab"
               withBranchB: @"abc"
                     gives: @"abbc"];
}

// FIXME: Support these cases
#if 0
- (void) testMergeOverlappingDeletions
{
    [self checkMergingBase: @"abcd"
               withBranchA: @"abc"
               withBranchB: @""
                     gives: @""];
}

- (void) testMergeBothSidesDelete
{
    [self checkMergingBase: @"abcd"
               withBranchA: @"ad"
               withBranchB: @"ad"
                     gives: @"ad"];
}
#endif

- (void)testMergeConflictingInserts
{
    COObjectGraphContext *ctx1 = [self makeAttributedString];
    [self appendString: @"a" htmlCode: nil toAttributedString: ctx1.rootObject];
    UKObjectsEqual(@"a",
                   [[[COAttributedStringWrapper alloc] initWithBacking: ctx1.rootObject] string]);

    COObjectGraphContext *ctx2 = [COObjectGraphContext new];
    [ctx2 setItemGraph: ctx1];
    [self appendString: @"bc" htmlCode: nil toAttributedString: ctx2.rootObject];
    UKObjectsEqual(@"abc",
                   [[[COAttributedStringWrapper alloc] initWithBacking: ctx2.rootObject] string]);

    COObjectGraphContext *ctx3 = [COObjectGraphContext new];
    [ctx3 setItemGraph: ctx1];
    [self appendString: @"def" htmlCode: nil toAttributedString: ctx3.rootObject];
    UKObjectsEqual(@"adef",
                   [[[COAttributedStringWrapper alloc] initWithBacking: ctx3.rootObject] string]);

    COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: ctx1.rootObject
                                                                            secondAttributedString: ctx2.rootObject
                                                                                            source: @"diff12"];

    COAttributedStringDiff *diff13 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: ctx1.rootObject
                                                                            secondAttributedString: ctx3.rootObject
                                                                                            source: @"diff13"];

    {
        COAttributedStringDiff *mergeA = [diff12 diffByMergingWithDiff: diff13];
        [mergeA resolveConflictsFavoringSourceIdentifier: @"diff12"];
        COObjectGraphContext *mergeAapplied = [[COObjectGraphContext alloc] init];
        [mergeAapplied setItemGraph: ctx1];
        [mergeA applyToAttributedString: mergeAapplied.rootObject];
        UKObjectsEqual(@"abcdef", [(COAttributedString *)mergeAapplied.rootObject string]);
    }
    {
        COAttributedStringDiff *mergeB = [diff12 diffByMergingWithDiff: diff13];
        [mergeB resolveConflictsFavoringSourceIdentifier: @"diff13"];
        COObjectGraphContext *mergeBapplied = [[COObjectGraphContext alloc] init];
        [mergeBapplied setItemGraph: ctx1];
        [mergeB applyToAttributedString: mergeBapplied.rootObject];
        UKObjectsEqual(@"adefbc", [(COAttributedString *)mergeBapplied.rootObject string]);
    }
}

#if 0

- (void) testMergeDeleteAndInsert
{
    COObjectGraphContext *ctx1 = [self makeAttributedString];
    [self appendString: @"abc" htmlCode: nil toAttributedString: ctx1.rootObject];
    UKObjectsEqual(@"abc", [ctx1.rootObject string]);
    
    COObjectGraphContext *ctx2 = [COObjectGraphContext new];
    [ctx2 setItemGraph: ctx1];
    [self clearAttributedString: ctx2.rootObject];
    UKObjectsEqual(@"", [ctx2.rootObject string]);
    
    COObjectGraphContext *ctx3 = [COObjectGraphContext new];
    [ctx3 setItemGraph: ctx1];
    [self clearAttributedString: ctx3.rootObject];
    [self appendString: @"dabcefg" htmlCode: nil toAttributedString: ctx3.rootObject];
    UKObjectsEqual(@"dabcefg", [ctx3.rootObject string]);
    
    COAttributedStringDiff *diff12 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: ctx1.rootObject
                                                                            secondAttributedString: ctx2.rootObject
                                                                                            source: @"diff12"];
    
    COAttributedStringDiff *diff13 = [[COAttributedStringDiff alloc] initWithFirstAttributedString: ctx1.rootObject
                                                                            secondAttributedString: ctx3.rootObject
                                                                                            source: @"diff13"];
    
    {
        COAttributedStringDiff *mergeA = [diff12 diffByMergingWithDiff: diff13];
        COObjectGraphContext *mergeAapplied = [[COObjectGraphContext alloc] init];
        [mergeAapplied setItemGraph: ctx1];
        [mergeA applyToAttributedString: mergeAapplied.rootObject];
        UKObjectsEqual(@"defg", [(COAttributedString *)mergeAapplied.rootObject string]);
    }
}

#endif

@end
