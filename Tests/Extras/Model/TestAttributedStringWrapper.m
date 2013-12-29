/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

typedef void (^EditedBlockType)(NSUInteger editedMask, NSRange range, NSInteger delta);

/**
 * Extended version of COAttributedStringWrapper that runs a block when
 * its -edited:range:changeInLength: method is called.
 */
@interface COAttributedStringWrapperTestExtensions : COAttributedStringWrapper
@property (nonatomic, strong) EditedBlockType editedBlock;
@end

@implementation COAttributedStringWrapperTestExtensions
@synthesize editedBlock;
- (void) edited: (NSUInteger)editedMask range: (NSRange)range changeInLength: (NSInteger)delta
{
	[super edited: editedMask range: range changeInLength: delta];
	
	if (self.editedBlock != nil)
	{
		self.editedBlock(editedMask, range, delta);
	}
}
@end


@interface TestAttributedStringWrapper : TestAttributedStringCommon <UKTest>
@end

@implementation TestAttributedStringWrapper

- (void) checkAttribute: (NSString *)attributeName hasValue: (id)expectedValue withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target
{
	NSRange actualRange;
	id actualValue = [target attribute: attributeName
							   atIndex: expectedRange.location
				 longestEffectiveRange: &actualRange
							   inRange: NSMakeRange(0, [target length])];
	
	if (expectedValue == nil)
	{
		UKNil(actualValue);
	}
	else
	{
		UKObjectsEqual(expectedValue, actualValue);
	}
	
	UKIntsEqual(expectedRange.location, actualRange.location);
	UKIntsEqual(expectedRange.length, actualRange.length);
}

- (void) checkFontHasTraits: (NSFontSymbolicTraits)traits withLongestEffectiveRange: (NSRange)expectedRange inAttributedString: (NSAttributedString *)target
{
	NSRange actualRange;
	NSFont *actualFont = [target attribute: NSFontAttributeName
								   atIndex: expectedRange.location
					 longestEffectiveRange: &actualRange
								   inRange: NSMakeRange(0, [target length])];
	
	NSFontSymbolicTraits actualTraits = [[actualFont fontDescriptor] symbolicTraits];
	
	UKTrue((actualTraits & traits) == traits);
	
	UKIntsEqual(expectedRange.location, actualRange.location);
	UKIntsEqual(expectedRange.length, actualRange.length);
}

- (void) testWrapperBasic
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"X" htmlCode: @"b" toAttributedString: [source rootObject]];
	[self appendString: @"Y" htmlCode: @"u" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: [source rootObject]];
	UKIntsEqual(2, [as length]);
	
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1, 1) inAttributedString: as];
	[self checkFontHasTraits: NSFontBoldTrait withLongestEffectiveRange: NSMakeRange(0, 1) inAttributedString: as];
}

- (void) testWrapperInsertCharacters
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"()" htmlCode: @"u" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: [source rootObject]];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"test"];
	
	UKObjectsEqual(@"(test)", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 6) inAttributedString: as];
}

- (void) testWrapperReplaceCharacters
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"()" htmlCode: @"u" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: [source rootObject]];
	[as replaceCharactersInRange: NSMakeRange(1, 1) withString: @">"];
	
	UKObjectsEqual(@"(>", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 2) inAttributedString: as];
}

- (void) testWrapperReplaceCharactersAcrossChunks
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: @"u" toAttributedString: [source rootObject]];
	[self appendString: @"def" htmlCode: @"b" toAttributedString: [source rootObject]];
	[self appendString: @"ghi" htmlCode: @"i" toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: [source rootObject]];
	[as replaceCharactersInRange: NSMakeRange(2, 5) withString: @"-"];
	
	UKObjectsEqual(@"ab-hi", [as string]);
	
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 3) inAttributedString: as];
	[self checkFontHasTraits: NSFontItalicTrait withLongestEffectiveRange: NSMakeRange(3, 2) inAttributedString: as];
}

- (void) testSetAttributes
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"abc" htmlCode: nil toAttributedString: [source rootObject]];
	
	COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: [source rootObject]];	
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSFont *bold = [fm convertFont: [NSFont userFontOfSize: 12] toHaveTrait: NSFontBoldTrait];
	NSFont *boldItalic = [fm convertFont: bold toHaveTrait: NSFontItalicTrait];
	
	[as setAttributes: @{NSFontAttributeName : bold} range: NSMakeRange(0, 1)];
	[as setAttributes: @{NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)} range: NSMakeRange(1, 1)];
	[as setAttributes: @{NSFontAttributeName : boldItalic} range: NSMakeRange(2, 1)];
	
	UKObjectsEqual(@"abc", [as string]);
	[self checkFontHasTraits: NSFontBoldTrait withLongestEffectiveRange: NSMakeRange(0, 1) inAttributedString: as];
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1, 1) inAttributedString: as];
	[self checkFontHasTraits: NSFontBoldTrait | NSFontItalicTrait withLongestEffectiveRange: NSMakeRange(2, 1) inAttributedString: as];
}

- (void) testTextStorageNotificationsCalled
{
	COObjectGraphContext *source = [self makeAttributedString];
	[self appendString: @"()" htmlCode: @"u" toAttributedString: [source rootObject]];
		
	COAttributedStringWrapperTestExtensions *as = [[COAttributedStringWrapperTestExtensions alloc] initWithBacking: [source rootObject]];
	__block int editedCalls = 0;
	as.editedBlock = ^(NSUInteger editedMask, NSRange range, NSInteger delta)
	{
		editedCalls++;
	};

	UKIntsEqual(0, editedCalls);
	[self appendString: @"()" htmlCode: @"i" toAttributedString: [source rootObject]];
	
	// TODO: Currently, a lot of redundant -edited:... calls are made
	UKFalse(0 == editedCalls);
}

@end
