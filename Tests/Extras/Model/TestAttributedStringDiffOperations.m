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
	COObjectGraphContext *target = [self makeAttributedString];
	[self appendString: @"()" htmlCode: @"i" toAttributedString: [target rootObject]];
	
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"X" htmlCode: @"b" toAttributedString: [source rootObject]];
	[self appendString: @"Y" htmlCode: @"u" toAttributedString: [source rootObject]];
	
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
	COObjectGraphContext *target = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: @"b" toAttributedString: [target rootObject]];
	[self appendString: @"def" htmlCode: @"u" toAttributedString: [target rootObject]];
	[self appendString: @"ghi" htmlCode: @"i" toAttributedString: [target rootObject]];
	
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
	COObjectGraphContext *target = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: @"b" toAttributedString: [target rootObject]];
	[self appendString: @"def" htmlCode: @"u" toAttributedString: [target rootObject]];
	[self appendString: @"ghi" htmlCode: @"i" toAttributedString: [target rootObject]];
	
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"X" htmlCode: @"i" toAttributedString: [source rootObject]];
	[self appendString: @"Y" htmlCode: @"u" toAttributedString: [source rootObject]];
	
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
	COObjectGraphContext *target = [self makeAttributedString];
	[self appendString: @"Hello World" htmlCode: nil toAttributedString: [target rootObject]];
	
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
	COObjectGraphContext *target = [self makeAttributedString];
	[self appendString: @"Hello World" htmlCode: @"b" toAttributedString: [target rootObject]];
	
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
