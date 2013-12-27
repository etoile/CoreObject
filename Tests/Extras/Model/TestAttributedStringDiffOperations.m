/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestAttributedStringDiffOperations : TestCase <UKTest>
@end

@implementation TestAttributedStringDiffOperations

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode inCtx: (COObjectGraphContext *)ctx
{
	COAttributedStringAttribute *attribute = [ctx insertObjectWithEntityName: @"COAttributedStringAttribute"];
	attribute.htmlCode = htmlCode;
	return attribute;
}

- (COObjectGraphContext *) makeAttributedString
{
	COObjectGraphContext *ctx1 = [COObjectGraphContext new];
	COAttributedString *ctx1String = [ctx1 insertObjectWithEntityName: @"COAttributedString"];
	ctx1.rootObject = ctx1String;
	return ctx1;
}

- (void) appendString: (NSString *)string htmlCode: (NSString *)aCode toAttributedString: (COAttributedString *)dest
{
	COObjectGraphContext *ctx = [dest objectGraphContext];
	COAttributedStringChunk *chunk = [ctx insertObjectWithEntityName: @"COAttributedStringChunk"];
	chunk.text = string;
	
	if (aCode != nil)
	{
		chunk.attributes = S([self makeAttr: aCode inCtx: ctx]);
	}

	[dest insertObject: chunk atIndex: ETUndeterminedIndex hint: nil forProperty: @"chunks"];
}


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
