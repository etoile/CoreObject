/*
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringDiffOperations : EditingContextTestCase <UKTest>
@end


@implementation TestAttributedStringDiffOperations

- (void)testInsertAttributedSubstring
{
    COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<i>()</i>"];
    COObjectGraphContext *source = [self makeAttributedString2WithHTML: @"<b>X</b><u>Y</u>"];

    COAttributedStringDiffOperationInsertAttributedSubstring *op = [COAttributedStringDiffOperationInsertAttributedSubstring new];
    op.range = NSMakeRange(1, 0);
    op.source = nil;
    op.attributedStringItemGraph = [[COItemGraph alloc] initWithItemGraph: source];

    NSInteger delta = [op applyOperationToAttributedString: target.rootObject withOffset: 0];
    UKIntsEqual(2, delta);

    [self checkCOAttributedString: target.rootObject
                       equalsHTML: @"<I>(</I><B>X</B><U>Y</U><I>)</I>"];
}

- (void)testDeleteRange
{
    COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<B>abc</B><U>def</U><I>ghi</I>"];

    COAttributedStringDiffOperationDeleteRange *op = [COAttributedStringDiffOperationDeleteRange new];
    op.range = NSMakeRange(2, 5);
    op.source = nil;

    NSInteger delta = [op applyOperationToAttributedString: target.rootObject withOffset: 0];
    UKIntsEqual(-5, delta);

    [self checkCOAttributedString: target.rootObject equalsHTML: @"<B>ab</B><I>hi</I>"];
}

- (void)testReplaceRange
{
    COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<B>abc</B><U>def</U><I>ghi</I>"];
    COObjectGraphContext *source = [self makeAttributedString2WithHTML: @"<I>X</I><U>Y</U>"];

    COAttributedStringDiffOperationReplaceRange *op = [COAttributedStringDiffOperationReplaceRange new];
    op.range = NSMakeRange(2, 5);
    op.attributedStringItemGraph = [[COItemGraph alloc] initWithItemGraph: source];
    op.source = nil;

    NSInteger delta = [op applyOperationToAttributedString: target.rootObject withOffset: 0];
    UKIntsEqual(-3, delta);

    [self checkCOAttributedString: target.rootObject
                       equalsHTML: @"<B>ab</B><I>X</I><U>Y</U><I>hi</I>"];
}

- (void)testAddAttribute
{
    COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"Hello World"];

    COObjectGraphContext *source = [COObjectGraphContext new];
    source.rootObject = [self makeAttr: @"b" inCtx: source];

    // Make 'World' bold
    COAttributedStringDiffOperationAddAttribute *op = [COAttributedStringDiffOperationAddAttribute new];
    op.range = NSMakeRange(6, 5);
    op.attributeItemGraph = [[COItemGraph alloc] initWithItemGraph: source];
    op.source = nil;

    NSInteger delta = [op applyOperationToAttributedString: target.rootObject withOffset: 0];
    UKIntsEqual(0, delta);

    [self checkCOAttributedString: target.rootObject equalsHTML: @"Hello <B>World</B>"];
}

- (void)testRemoveAttribute
{
    COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<B>Hello World</B>"];

    COObjectGraphContext *source = [COObjectGraphContext new];
    source.rootObject = [self makeAttr: @"b" inCtx: source];

    // Make 'World' un-bold
    COAttributedStringDiffOperationRemoveAttribute *op = [COAttributedStringDiffOperationRemoveAttribute new];
    op.range = NSMakeRange(6, 5);
    op.attributeItemGraph = [[COItemGraph alloc] initWithItemGraph: source];
    op.source = nil;

    NSInteger delta = [op applyOperationToAttributedString: target.rootObject withOffset: 0];
    UKIntsEqual(0, delta);

    [self checkCOAttributedString: target.rootObject equalsHTML: @"<B>Hello </B>World"];
}

@end
