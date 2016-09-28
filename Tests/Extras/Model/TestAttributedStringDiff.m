/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringDiff : EditingContextTestCase <UKTest>
@end


@implementation TestAttributedStringDiff

- (void)testDiffInsertionWithAttribute
{
    [self checkDiffHTML: @"()x"
               withHTML: @"(a<B>bc</B>)<I>x</I>"
        givesOperations: S([self insertHTML: @"a<B>bc</B>" atIndex: 1],
                           [self addAttributeOp: @"i" inRange: NSMakeRange(2, 1)])];
}

- (void)testDiffInsertionWithAttribute2
{
    [self checkDiffHTML: @"()cd"
               withHTML: @"(ab)<B>c</B>d"
        givesOperations: S([self insertHTML: @"ab" atIndex: 1],
                           [self addAttributeOp: @"b" inRange: NSMakeRange(2, 1)])];
}

- (void)testDiffInsertionAtStart
{
    [self checkDiffHTML: @"aba"
               withHTML: @"xaba"
        givesOperations: S([self insertHTML: @"x" atIndex: 0])];
}

- (void)testDiffInsertionAtEnd
{
    [self checkDiffHTML: @"aba"
               withHTML: @"abax"
        givesOperations: S([self insertHTML: @"x" atIndex: 3])];
}

- (void)testDiffTwoInsertions
{
    [self checkDiffHTML: @"()[]"
               withHTML: @"(first)[second]"
        givesOperations: S([self insertHTML: @"first" atIndex: 1],
                           [self insertHTML: @"second" atIndex: 3])];
}

- (void)testDiffInsertionUsingAttributeToRight1
{
    [self checkDiffHTML: @"<B>x</B><I>z</I>"
               withHTML: @"<B>x</B><I>yz</I>"
        givesOperations: S([self insertHTML: @"<I>y</I>" atIndex: 1])];
}

- (void)testDiffInsertionUsingAttributeToRight2
{
    [self checkDiffHTML: @"<B>x</B>"
               withHTML: @"<B>wx</B>"
        givesOperations: S([self insertHTML: @"<B>w</B>" atIndex: 0])];
}

- (void)testDiffDeletionAcrossAttributes
{
    [self checkDiffHTML: @"<B>abc</B><I>def</I><U>ghi</U>"
               withHTML: @"<B>a</B><U>i</U>"
        givesOperations: S([self deleteRangeOp: NSMakeRange(1, 7)])];
}

- (void)testDiffDeletionAndInsertion
{
    [self checkDiffHTML: @"()[]"
               withHTML: @"[test]"
        givesOperations: S([self deleteRangeOp: NSMakeRange(0, 2)],
                           [self insertHTML: @"test" atIndex: 3])];
}

- (void)testDiffEmptyString
{
    [self checkDiffHTML: @""
               withHTML: @""
        givesOperations: S()];
}

- (void)testDiffSameString
{
    [self checkDiffHTML: @"x"
               withHTML: @"x"
        givesOperations: S()];
}

- (void)testDiffReplacement
{
    [self checkDiffHTML: @"<B>abcdefg</B>"
               withHTML: @"<B>ab</B><U>CDE</U><B>fg</B>"
        givesOperations: S([self replaceRangeOp: NSMakeRange(2, 3) withHTML: @"<U>CDE</U>"])];
}

- (void)testDiffAddAttribute
{
    [self checkDiffHTML: @"abc<I>def</I><U>ghi</U>"
               withHTML: @"ab<B>c<I>def</I><U>g</B>hi</U>"
        givesOperations: S([self addAttributeOp: @"b" inRange: NSMakeRange(2, 5)])];
}

- (void)testDiffRemoveAttribute
{
    [self checkDiffHTML: @"ab<B>c<I>def</I><U>g</B>hi</U>"
               withHTML: @"abc<I>def</I><U>ghi</U>"
        givesOperations: S([self removeAttributeOp: @"b" inRange: NSMakeRange(2, 5)])];
}

- (void)testDiffAddAttribute2
{
    [self checkDiffHTML: @"abc"
               withHTML: @"<B>ab</B>c"
        givesOperations: S([self addAttributeOp: @"b" inRange: NSMakeRange(0, 2)])];
}

- (void)testDiffAddAttribute3
{
    [self checkDiffHTML: @"abc"
               withHTML: @"a<B>bc</B>"
        givesOperations: S([self addAttributeOp: @"b" inRange: NSMakeRange(1, 2)])];
}

- (void)testDiffAddAttributeAndText
{
    [self checkDiffHTML: @"abc"
               withHTML: @"da<I>bc</I>"
        givesOperations: S([self insertHTML: @"d" atIndex: 0],
                           [self addAttributeOp: @"i" inRange: NSMakeRange(1, 2)])];
}

@end
