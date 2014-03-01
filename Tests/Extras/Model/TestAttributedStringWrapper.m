/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

/**
 * Extended version of COAttributedStringWrapper that logs calls to
 * -edited:range:changeInLength:
 */
@interface COAttributedStringWrapperTestExtensions : COAttributedStringWrapper
{
}
@end

static void
LogEditedCall(NSUInteger editedMask, NSRange range, NSInteger delta)
{
	NSString *mask = @"";
	if ((editedMask & NSTextStorageEditedCharacters) == NSTextStorageEditedCharacters)
	{
		mask = [mask stringByAppendingString: @"NSTextStorageEditedCharacters"];
	}
	if ((editedMask & NSTextStorageEditedAttributes) == NSTextStorageEditedAttributes)
	{
		if ([mask length] > 0)
		{
			mask = [mask stringByAppendingString: @"|"];
		}
		mask = [mask stringByAppendingString: @"NSTextStorageEditedAttributes"];
	}
	
	NSLog(@"edited: %@ range: %@ changeInLength: %d", mask, NSStringFromRange(range), (int)delta);
}

@implementation COAttributedStringWrapperTestExtensions

- (void) edited: (NSUInteger)editedMask range: (NSRange)range changeInLength: (NSInteger)delta
{
	LogEditedCall(editedMask, range, delta);
	[super edited: editedMask range: range changeInLength: delta];
}

@end


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

- (void) edited: (NSUInteger)editedMask range: (NSRange)range changeInLength: (NSInteger)delta
{
	LogEditedCall(editedMask, range, delta);
	[super edited: editedMask range: range changeInLength: delta];
}

@end

/**
 * Abstract class for tests that test an NSTextStorage subclass
 */
#ifdef GNUSTEP
@interface AbstractTextStorageTests : EditingContextTestCase
#else
@interface AbstractTextStorageTests : EditingContextTestCase <NSTextStorageDelegate>
#endif
{
	NSTextStorage *as;
	
	BOOL _didProcessEditing;
	NSRange _lastEditedRange;
	NSInteger _lastEditedMask;
	NSInteger _lastChangeInLength;
}
@end

@implementation AbstractTextStorageTests

- (void)textStorageWillProcessEditing:(NSNotification *)notification
{
	_didProcessEditing = YES;
	_lastEditedRange = [as editedRange];
	_lastEditedMask = [as editedMask];
	_lastChangeInLength = [as changeInLength];
}

/**
 * Executes a block that should make some modifications to 'as',
 * and check that the modification has the expected side effects.
 * 
 * The block is executed between calls to -beginEditing and -endEditing.
 */
- (void) checkBlock: (void (^)(void))aBlock modifiesRange: (NSRange)aRange mask: (NSInteger)aMask delta: (NSInteger)delta newString: (NSString *)newString
{
	_didProcessEditing = NO;
	
	[as setDelegate: self];
	[as beginEditing];
	aBlock();
	[as endEditing];
	
	if (!_didProcessEditing)
	{
		UKFail();
	}
	else
	{
		UKTrue(NSEqualRanges(aRange, _lastEditedRange));
		UKIntsEqual(aMask, _lastEditedMask);
		UKIntsEqual(delta, _lastChangeInLength);
		UKObjectsEqual(newString, [as string]);
		UKIntsEqual([newString length], [as length]);
	}
}

- (void) testBasic
{
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0,0) withString: @"XY"];
		[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0,1) inTextStorage: as];
		[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(1, 1)];
	} modifiesRange: NSMakeRange(0, 2) mask: NSTextStorageEditedAttributes | NSTextStorageEditedCharacters delta: 2 newString: @"XY"];

	[self checkFontHasTraits: NSFontBoldTrait withLongestEffectiveRange: NSMakeRange(0, 1) inAttributedString: as];
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1, 1) inAttributedString: as];
}

- (void) testInsertCharacters
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"()"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 2)];
	
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"test"];
	} modifiesRange: NSMakeRange(1, 4) mask: NSTextStorageEditedCharacters delta: 4 newString: @"(test)"];
	
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 6) inAttributedString: as];
}

- (void) testReplaceCharacters
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"()"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 2)];
	
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(1, 1) withString: @">"];
	} modifiesRange: NSMakeRange(1, 1) mask: NSTextStorageEditedCharacters delta: 0 newString: @"(>"];
	
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 2) inAttributedString: as];
}

- (void) testReplaceCharactersAcrossAttributes
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"abcdefghi"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 3)];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(3,3) inTextStorage: as];
	[self setFontTraits: NSFontItalicTrait inRange: NSMakeRange(6,3) inTextStorage: as];
	
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(2, 5) withString: @"-"];
	} modifiesRange: NSMakeRange(2, 1) mask: NSTextStorageEditedCharacters delta: -4 newString: @"ab-hi"];
	
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 3) inAttributedString: as];
	[self checkFontHasTraits: NSFontItalicTrait withLongestEffectiveRange: NSMakeRange(3, 2) inAttributedString: as];
}

- (void) testInsertInEmptyString
{
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	} modifiesRange: NSMakeRange(0, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"a"];
}

- (void) testInsertAtEndOfString
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
	} modifiesRange: NSMakeRange(1, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"ab"];
}

- (void) testInsertAfterTwoChunks
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(1, 1)];
	
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(2, 0) withString: @"c"];
	} modifiesRange: NSMakeRange(2, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"abc"];
}

- (void) testLongestEffectiveRange
{
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	} modifiesRange: NSMakeRange(0, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"a"];

	NSRange longestEffectiveRange;
	id value = [as attribute: @"foo"
					 atIndex: 0
	   longestEffectiveRange: &longestEffectiveRange
					 inRange: NSMakeRange(0, 1)];
	
	UKNil(value);
	UKIntsEqual(0, longestEffectiveRange.location);
	UKIntsEqual(1, longestEffectiveRange.length);
}

- (void) testAttributeAtIndex
{
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
		[as setAttributes: @{ NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle) } range: NSMakeRange(0, 1)];
	} modifiesRange: NSMakeRange(0, 1) mask: NSTextStorageEditedCharacters | NSTextStorageEditedAttributes delta: 1 newString: @"a"];
	
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

- (void) testEraseAndAdd
{
	// Add "<b>1</b>23"
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"1"];
		[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"2"];
		[as replaceCharactersInRange: NSMakeRange(2, 0) withString: @"3"];
		[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0, 1) inTextStorage: as];
	} modifiesRange: NSMakeRange(0, 3) mask: NSTextStorageEditedCharacters | NSTextStorageEditedAttributes delta: 3 newString: @"123"];

	// Erase it
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, [as length]) withString: @""];
	} modifiesRange: NSMakeRange(0, 0) mask: NSTextStorageEditedCharacters delta: -3 newString: @""];
	
	// Add "x"
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"x"];
	} modifiesRange: NSMakeRange(0, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"x"];

	[self checkFontHasTraits: 0 withLongestEffectiveRange: NSMakeRange(0, 1) inAttributedString: as];
}

@end


/**
 * Concrete subclass of AbstractTextStorageTests that tests 
 * COAttributedStringWrapper
 */
@interface COAttributedStringWrapperTextStorageTests : AbstractTextStorageTests <UKTest>
{
	COObjectGraphContext *objectGraph;
	COAttributedString *attributedString;
	NSTextView *tv;
}
@end

@implementation COAttributedStringWrapperTextStorageTests

- (instancetype) init
{
	self = [super init];
		
	objectGraph = [self makeAttributedString];
	attributedString = [objectGraph rootObject];
	as = [[COAttributedStringWrapperTestExtensions alloc] initWithBacking: attributedString];
	
	tv = [[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
	[as addLayoutManager: [tv layoutManager]];
	
	return self;
}

- (void) dealloc
{
	[as removeLayoutManager: [tv layoutManager]];
}

- (void) testObjectGraphEdits
{
	[self checkBlock: ^() {
		[self appendString: @"abc" htmlCode: nil toAttributedString: [objectGraph rootObject]];
	} modifiesRange: NSMakeRange(0, 3) mask: NSTextStorageEditedCharacters delta: 3 newString: @"abc"];

	[self checkBlock: ^() {
		((COAttributedStringChunk *)attributedString.chunks[0]).text = @"ac";
	} modifiesRange: NSMakeRange(1, 0) mask: NSTextStorageEditedCharacters delta: -1 newString: @"ac"];

	[self checkBlock: ^() {
		((COAttributedStringChunk *)attributedString.chunks[0]).text = @"abc";
	} modifiesRange: NSMakeRange(1, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"abc"];
}

- (void) testTypeSingleCharacter
{
	// Set up a clone of objectGraph, type a single character in it
	COObjectGraphContext *remoteCtx = [COObjectGraphContext new];
	[remoteCtx setItemGraph: objectGraph];
	[self appendString: @"x" htmlCode: nil toAttributedString: [remoteCtx rootObject]];
	
	// Replicate that change to objectGraph
	[self checkBlock: ^() {
		[objectGraph setItemGraph: remoteCtx];
	} modifiesRange: NSMakeRange(0, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"x"];
}

- (void) testBoldingSingleCharacter
{
	[self appendString: @"abc" htmlCode: nil toAttributedString: attributedString];
	
	// Set up a clone of objectGraph, and make the "c" bold
	COObjectGraphContext *remoteCtx = [COObjectGraphContext new];
	[remoteCtx setItemGraph: objectGraph];
	COAttributedStringWrapper *remoteCtxWrapper = [[COAttributedStringWrapper alloc] initWithBacking: [remoteCtx rootObject]];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(2, 1) inTextStorage: remoteCtxWrapper];
		
	// Replicate that change to objectGraph
	[self checkBlock: ^() {
		[objectGraph setItemGraph: remoteCtx];
	} modifiesRange: NSMakeRange(2, 1) mask: NSTextStorageEditedCharacters | NSTextStorageEditedAttributes delta: 0 newString: @"abc"];
}

- (void) testTypeTwoCharactersAndRevert
{
	// 'x'
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"x"];
	} modifiesRange: NSMakeRange(0, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"x"];
	
	// Create snapshot1 from objectGraph
	COObjectGraphContext *snapshot1 = [COObjectGraphContext new];
	[snapshot1 setItemGraph: objectGraph];

	// 'xy'
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"y"];
	} modifiesRange: NSMakeRange(1, 1) mask: NSTextStorageEditedCharacters delta: 1 newString: @"xy"];
	
	// restore to snapshot1
	[self checkBlock: ^() {
		[objectGraph setItemGraph: snapshot1];
	} modifiesRange: NSMakeRange(1, 0) mask: NSTextStorageEditedCharacters delta: -1 newString: @"x"];
}

- (void) testDeleteMultipleChunks
{
	// 'a<b>b</b><i>c</i>'
	[self checkBlock: ^() {
		[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"abc"];
		[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(1,1) inTextStorage:as];
		[self setFontTraits: NSFontItalicTrait inRange: NSMakeRange(2,1) inTextStorage:as];
	} modifiesRange: NSMakeRange(0, 3) mask: NSTextStorageEditedCharacters | NSTextStorageEditedAttributes delta: 3 newString: @"abc"];
	
	// Create branch1 from objectGraph
	COObjectGraphContext *branch1 = [COObjectGraphContext new];
	[branch1 setItemGraph: objectGraph];
	
	// Erase '<b>b</b><i>c</i>' in the snapshot, append '<u>d</u>'
	[[branch1 rootObject] setChunks: @[[[[branch1 rootObject] chunks] firstObject]]];
	[self appendString: @"d" htmlCode: @"u" toAttributedString: [branch1 rootObject]];
	
	// revert objectGraph to branch1
	[self checkBlock: ^() {
		[objectGraph setItemGraph: branch1];
	} modifiesRange: NSMakeRange(1, 1) mask: NSTextStorageEditedCharacters | NSTextStorageEditedAttributes delta: -1 newString: @"ad"];
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
#ifndef GNUSTEP
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
#endif
