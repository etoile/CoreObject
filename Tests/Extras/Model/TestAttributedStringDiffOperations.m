/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringDiffOperations : EditingContextTestCase <UKTest>
@end

@implementation TestAttributedStringDiffOperations

- (void) testInsertAttributedSubstring
{
	COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<i>()</i>"];
	COObjectGraphContext *source = [self makeAttributedString2WithHTML: @"<b>X</b><u>Y</u>"];

	COAttributedStringDiffOperationInsertAttributedSubstring *op = [COAttributedStringDiffOperationInsertAttributedSubstring new];
	op.range = NSMakeRange(1, 0);
	op.source = nil;
	op.attributedStringItemGraph = [[COItemGraph alloc] initWithItemGraph: source];

	NSInteger delta = [op applyOperationToAttributedString: [target rootObject] withOffset: 0];
	UKIntsEqual(2, delta);

	UKObjectsEqual(A(@"(", @"X", @"Y", @")"), [[target rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(@"i"), S(@"b"), S(@"u"), S(@"i")), [[target rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

- (void) testDeleteRange
{
	COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<B>abc</B><U>def</U><I>ghi</I>"];
	
	COAttributedStringDiffOperationDeleteRange *op = [COAttributedStringDiffOperationDeleteRange new];
	op.range = NSMakeRange(2, 5);
	op.source = nil;
	
	NSInteger delta = [op applyOperationToAttributedString: [target rootObject] withOffset: 0];
	UKIntsEqual(-5, delta);
	
	UKObjectsEqual(A(@"ab", @"hi"), [[target rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(@"b"), S(@"i")), [[target rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

- (void) testReplaceRange
{
	COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<B>abc</B><U>def</U><I>ghi</I>"];
	COObjectGraphContext *source = [self makeAttributedString2WithHTML: @"<I>X</I><U>Y</U>"];
	
	COAttributedStringDiffOperationReplaceRange *op = [COAttributedStringDiffOperationReplaceRange new];
	op.range = NSMakeRange(2, 5);
	op.attributedStringItemGraph = [[COItemGraph alloc] initWithItemGraph: source];
	op.source = nil;
	
	NSInteger delta = [op applyOperationToAttributedString: [target rootObject] withOffset: 0];
	UKIntsEqual(-3, delta);
	
	UKObjectsEqual(A(@"ab", @"X", @"Y", @"hi"), [[target rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(@"b"), S(@"i"), S(@"u"), S(@"i")), [[target rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

- (void) testAddAttribute
{
	COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"Hello World"];
	
	COObjectGraphContext *source = [COObjectGraphContext new];
	[source setRootObject: [self makeAttr: @"b" inCtx: source]];
	
	// Make 'World' bold
	COAttributedStringDiffOperationAddAttribute *op = [COAttributedStringDiffOperationAddAttribute new];
	op.range = NSMakeRange(6, 5);
	op.attributeItemGraph = [[COItemGraph alloc] initWithItemGraph: source];
	op.source = nil;
	
	NSInteger delta = [op applyOperationToAttributedString: [target rootObject] withOffset: 0];
	UKIntsEqual(0, delta);
	
	UKObjectsEqual(A(@"Hello ", @"World"), [[target rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(), S(@"b")), [[target rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

- (void) testRemoveAttribute
{
	COObjectGraphContext *target = [self makeAttributedStringWithHTML: @"<B>Hello World</B>"];
	
	COObjectGraphContext *source = [COObjectGraphContext new];
	[source setRootObject: [self makeAttr: @"b" inCtx: source]];
	
	// Make 'World' un-bold
	COAttributedStringDiffOperationRemoveAttribute *op = [COAttributedStringDiffOperationRemoveAttribute new];
	op.range = NSMakeRange(6, 5);
	op.attributeItemGraph = [[COItemGraph alloc] initWithItemGraph: source];
	op.source = nil;
	
	NSInteger delta = [op applyOperationToAttributedString: [target rootObject] withOffset: 0];
	UKIntsEqual(0, delta);
	
	UKObjectsEqual(A(@"Hello ", @"World"), [[target rootObject] valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(@"b"), S()), [[target rootObject] valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

@end
