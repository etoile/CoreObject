/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestAttributedString : EditingContextTestCase <UKTest>
@end

@implementation TestAttributedString

- (void) testSplit
{
	COObjectGraphContext *target = [self makeAttributedString];
	COAttributedString *as = [target rootObject];
	COAttributedStringChunk *chunk0 = [self appendString: @"xy" htmlCode: @"b" toAttributedString: as];
	
	[as splitChunkAtIndex: 1];
	
	COAttributedStringChunk *chunk1 = as.chunks[1];
	
	// TODO: Check updated, inserted objects
}

@end
