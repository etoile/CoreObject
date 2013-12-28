/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedStringDiffOperations : TestAttributedStringCommon <UKTest>
@end

@implementation TestAttributedStringDiffOperations

- (void) testInsertAttributedSubstring
{
	COObjectGraphContext *target = [self makeAttributedString];
	[self appendString: @"()" htmlCode: nil toAttributedString: [target rootObject]];
	
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"X" htmlCode: @"b" toAttributedString: [source rootObject]];
	[self appendString: @"Y" htmlCode: @"u" toAttributedString: [source rootObject]];
	
	COAttributedStringDiffOperationInsertAttributedSubstring *op = [COAttributedStringDiffOperationInsertAttributedSubstring new];
	op.range = NSMakeRange(1, 0);
	op.source = nil;
	op.attributedStringItemGraph = [[COItemGraph alloc] initWithItemGraph: source];

	NSInteger delta = [op applyOperationToAttributedString: [target rootObject] withOffset: 0];
	UKIntsEqual(2, delta);

	UKObjectsEqual((@[@"(", @"X", @"Y", @")"]), [[[(COAttributedString *)[target rootObject] chunks] mappedCollection] text]);
	
	// TODO: Check that the attributes are correct
}

@end
