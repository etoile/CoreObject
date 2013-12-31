/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

//typedef void (^EditedBlockType)(NSUInteger editedMask, NSRange range, NSInteger delta);
//
///**
// * Extended version of COAttributedStringWrapper that runs a block when
// * its -edited:range:changeInLength: method is called.
// */
//@interface COAttributedStringWrapperTestExtensions : COAttributedStringWrapper
//@property (nonatomic, strong) EditedBlockType editedBlock;
//@end
//
//@implementation COAttributedStringWrapperTestExtensions
//@synthesize editedBlock;
//- (void) edited: (NSUInteger)editedMask range: (NSRange)range changeInLength: (NSInteger)delta
//{
//	[super edited: editedMask range: range changeInLength: delta];
//	
//	if (self.editedBlock != nil)
//	{
//		self.editedBlock(editedMask, range, delta);
//	}
//}
//@end


@interface SimpleTextStorage : NSTextStorage
{
	NSMutableAttributedString *_backing;
}
@end

@implementation SimpleTextStorage

- (id) init
{
    self = [super init];
	_backing = [[NSMutableAttributedString alloc] init];
    return self;
}

- (NSString *) string
{
    return [_backing string];
}

- (NSDictionary *) attributesAtIndex: (NSUInteger)anIndex effectiveRange: (NSRangePointer)rangeOut
{
	return [_backing attributesAtIndex: anIndex effectiveRange: rangeOut];
}

- (void) replaceCharactersInRange: (NSRange)aRange withString: (NSString *)aString
{
    [_backing replaceCharactersInRange: aRange withString: aString];
	[self edited: NSTextStorageEditedCharacters range: aRange changeInLength: [aString length] - aRange.length];
}

- (void) setAttributes: (NSDictionary *)attributes range: (NSRange)aRange
{
    [_backing setAttributes: attributes range: aRange];
	[self edited: NSTextStorageEditedAttributes range: aRange changeInLength: 0];
}

//- (id) attribute: (NSString *)attrName atIndex: (NSUInteger)location longestEffectiveRange: (NSRangePointer)range inRange: (NSRange)rangeLimit
//{
//	// HACK:
//	if (NSMaxRange(rangeLimit) > [self length])
//	{
//		rangeLimit.length -= (NSMaxRange(rangeLimit) - [self length]);
//	}
//	
//	id result = [super attribute: attrName atIndex: location longestEffectiveRange: range inRange: rangeLimit];
//	return result;
//}

@end


/**
 * Abstract class for tests that test an NSTextStorage subclass
 */
@interface AbstractTextStorageTests : TestAttributedStringCommon
{
	NSTextStorage *as;
}
@end

@implementation AbstractTextStorageTests

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

- (void) setFontTraits: (NSFontSymbolicTraits)traits inRange: (NSRange)aRange inTextStorage: (NSTextStorage *)target
{
	NSFont *font = [[NSFontManager sharedFontManager] convertFont: [NSFont userFontOfSize: 12] toHaveTrait: traits];
	[target addAttribute: NSFontAttributeName
				   value: font
				   range: aRange];
}

- (void) testBasic
{
	[as replaceCharactersInRange: NSMakeRange(0,0) withString: @"XY"];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0,1) inTextStorage: as];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(1, 1)];

	UKIntsEqual(2, [as length]);
	[self checkFontHasTraits: NSFontBoldTrait withLongestEffectiveRange: NSMakeRange(0, 1) inAttributedString: as];
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1, 1) inAttributedString: as];	
}

- (void) testInsertCharacters
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"()"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 2)];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"test"];
	
	UKObjectsEqual(@"(test)", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 6) inAttributedString: as];
}

- (void) testReplaceCharacters
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"()"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 2)];
	[as replaceCharactersInRange: NSMakeRange(1, 1) withString: @">"];
	
	UKObjectsEqual(@"(>", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 2) inAttributedString: as];
}

- (void) testReplaceCharactersAcrossAttributes
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"abcdefghi"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 3)];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(3,3) inTextStorage: as];
	[self setFontTraits: NSFontItalicTrait inRange: NSMakeRange(6,3) inTextStorage: as];
	[as replaceCharactersInRange: NSMakeRange(2, 5) withString: @"-"];
	
	UKObjectsEqual(@"ab-hi", [as string]);
	
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 3) inAttributedString: as];
	[self checkFontHasTraits: NSFontItalicTrait withLongestEffectiveRange: NSMakeRange(3, 2) inAttributedString: as];
}

//- (void) testTextStorageNotificationsCalled
//{
//	COObjectGraphContext *source = [self makeAttributedString];
//	[self appendString: @"()" htmlCode: @"u" toAttributedString: [source rootObject]];
//	
//	COAttributedStringWrapperTestExtensions *as = [[COAttributedStringWrapperTestExtensions alloc] initWithBacking: [source rootObject]];
//	__block int editedCalls = 0;
//	as.editedBlock = ^(NSUInteger editedMask, NSRange range, NSInteger delta)
//	{
//		editedCalls++;
//	};
//	
//	UKIntsEqual(0, editedCalls);
//	[self appendString: @"()" htmlCode: @"i" toAttributedString: [source rootObject]];
//	
//	// TODO: Currently, a lot of redundant -edited:... calls are made
//	UKFalse(0 == editedCalls);
//}

- (void) testInsertInEmptyString
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	UKObjectsEqual(@"a", [as string]);
}

- (void) testInsertAtEndOfString
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
	
	UKObjectsEqual(@"ab", [as string]);
}

- (void) testInsertAfterTwoChunks
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(1, 1)];
	[as replaceCharactersInRange: NSMakeRange(2, 0) withString: @"c"];
	
	UKObjectsEqual(@"abc", [as string]);
}

- (void) testLongestEffectiveRange
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	NSRange longestEffectiveRange;
	id value = [as attribute: @"foo"
					 atIndex: 0
	   longestEffectiveRange: &longestEffectiveRange
					 inRange: NSMakeRange(0, 1)];
//					 inRange: NSMakeRange(0, 2)]; /* We need to handle the range spuriously extending beyond the string length */
	
	UKNil(value);
	UKIntsEqual(0, longestEffectiveRange.location);
	UKIntsEqual(1, longestEffectiveRange.length);
}

- (void) testAttributeAtIndex
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	[as setAttributes: @{ NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle) } range: NSMakeRange(0, 1)];
	
	NSRange effectiveRange;
	UKObjectsEqual(@(NSUnderlineStyleSingle), [as attribute: NSUnderlineStyleAttributeName atIndex: 0 effectiveRange: &effectiveRange]);
	UKRaisesException([as attribute: @"foo" atIndex: 1 effectiveRange: &effectiveRange]);
}

- (void) testNonExistentAttributeAtStart
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	NSRange effectiveRange;
	id value = [as attribute: NSUnderlineStyleAttributeName
					 atIndex: 0
			  effectiveRange: &effectiveRange];
	
	UKNil(value);
	UKIntsEqual(0, effectiveRange.location);
	UKIntsEqual(1, effectiveRange.length);
}

- (void) testNonExistentAttributeAtEnd
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	NSRange effectiveRange;
	UKRaisesException([as attribute: NSUnderlineStyleAttributeName atIndex: 1 effectiveRange: &effectiveRange]);
}

- (void) testReadAttributeInEmptyString
{
	NSRange effectiveRange;
	UKRaisesException([as attribute: NSUnderlineStyleAttributeName atIndex: 0 effectiveRange: &effectiveRange]);
}

@end



/**
 * Concrete subclass of AbstractTextStorageTests that tests 
 * COAttributedStringWrapper
 */
@interface COAttributedStringWrapperTextStorageTests : AbstractTextStorageTests <UKTest>
{
	COObjectGraphContext *objectGraph;
}
@end

@implementation COAttributedStringWrapperTextStorageTests

- (instancetype) init
{
	self = [super init];
	objectGraph = [self makeAttributedString];
	as = [[COAttributedStringWrapper alloc] initWithBacking: [objectGraph rootObject]];
	return self;
}

@end



/**
 * Concrete subclass of AbstractTextStorageTests that tests
 * SimpleTextStorage
 */
@interface SimpleTextStorageTextStorageTests : AbstractTextStorageTests <UKTest>
@end

@implementation SimpleTextStorageTextStorageTests

- (instancetype) init
{
	self = [super init];
	as = [[SimpleTextStorage alloc] init];
	return self;
}

@end



/**
 * Concrete subclass of AbstractTextStorageTests that uses a NSTextView's text storage
 */
@interface NSTextViewTextStorageTests : AbstractTextStorageTests <UKTest>
@end

@implementation NSTextViewTextStorageTests

- (instancetype) init
{
	self = [super init];
	as = [[[NSTextView alloc] init] textStorage];
	return self;
}

@end
