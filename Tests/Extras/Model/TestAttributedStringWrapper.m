/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

/**
 * Record of a call to -[NSTextStorage edited:range:changeInLength:]
 */
@interface EditedCall : NSObject
@property (nonatomic) NSUInteger editedMask;
@property (nonatomic) NSRange range;
@property (nonatomic) NSInteger changeInLength;
+ (EditedCall *) edited: (NSUInteger)editedMask range: (NSRange)range changeInLength: (NSInteger)delta;
@end

@implementation EditedCall
@synthesize editedMask, range, changeInLength;
+ (EditedCall *) edited: (NSUInteger)editedMask range: (NSRange)range changeInLength: (NSInteger)delta
{
	EditedCall *result = [EditedCall new];
	result.editedMask = editedMask;
	result.range = range;
	result.changeInLength = delta;
	return result;
}
- (NSUInteger)hash
{
	return editedMask ^ range.location ^ range.length ^ changeInLength;
}
- (BOOL) isEqual:(id)object
{
	if (![object isKindOfClass: [EditedCall class]])
		return NO;
	
	EditedCall *other = (EditedCall *)object;
	return other.editedMask == editedMask
		&& NSEqualRanges(other.range, range)
		&& other.changeInLength == changeInLength;
}
- (NSString *)description
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
	
	return [NSString stringWithFormat: @"<EditedCall mask: %@ range: %@ changeInLength: %d>",
			mask,
			NSStringFromRange(range),
			(int)changeInLength];
}
@end



@protocol EditedCallLogging
- (void) clearEditCalls;
/**
 * Returns an array of EditedCall objects representing the calls to
 * -edited:range:changeInLength: with the character edit mask set, since the last call to clearEditCalls
 */
- (NSArray *) characterEditCalls;
@end



/**
 * Extended version of COAttributedStringWrapper that logs calls to
 * -edited:range:changeInLength:
 */
@interface COAttributedStringWrapperTestExtensions : COAttributedStringWrapper <EditedCallLogging>
{
	NSMutableArray *_editedCalls;
}
@end

@implementation COAttributedStringWrapperTestExtensions

- (void) edited: (NSUInteger)editedMask range: (NSRange)range changeInLength: (NSInteger)delta
{
	if (_editedCalls == nil)
		_editedCalls = [NSMutableArray new];
	[_editedCalls addObject: [EditedCall edited: editedMask range: range changeInLength: delta]];
		
	[super edited: editedMask range: range changeInLength: delta];
}

- (void) clearEditCalls
{
	[_editedCalls removeAllObjects];
}

- (NSArray *) characterEditCalls
{
	return [_editedCalls filteredCollectionWithBlock: ^(id obj) {
		return (BOOL)([(EditedCall *)obj editedMask] & NSTextStorageEditedCharacters);
	}];
}

@end



@interface SimpleTextStorage : NSTextStorage <EditedCallLogging>
{
	NSMutableAttributedString *_backing;
	NSMutableArray *_editedCalls;
}
@end

@implementation SimpleTextStorage

- (id) init
{
    self = [super init];
	_backing = [[NSMutableAttributedString alloc] init];
	_editedCalls = [NSMutableArray new];
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
	[_editedCalls addObject: [EditedCall edited: editedMask range: range changeInLength: delta]];
	[super edited: editedMask range: range changeInLength: delta];
}

- (void) clearEditCalls
{
	[_editedCalls removeAllObjects];
}

- (NSArray *) characterEditCalls
{
	return [_editedCalls filteredCollectionWithBlock: ^(id obj) {
		return (BOOL)([(EditedCall *)obj editedMask] & NSTextStorageEditedCharacters);
	}];
}

@end


/**
 * Abstract class for tests that test an NSTextStorage subclass
 */
@interface AbstractTextStorageTests : EditingContextTestCase
{
	NSTextStorage *as;
}
@end

@implementation AbstractTextStorageTests

- (void) checkCharacterEdits: (NSArray *)expected
{
	if ([as conformsToProtocol: @protocol(EditedCallLogging)])
	{
		NSArray *actual = [(id<EditedCallLogging>)as characterEditCalls];
		UKObjectsEqual(expected, actual);
		
		[(id<EditedCallLogging>)as clearEditCalls];
	}
}

- (void) testBasic
{
	[as replaceCharactersInRange: NSMakeRange(0,0) withString: @"XY"];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0,1) inTextStorage: as];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(1, 1)];

	UKIntsEqual(2, [as length]);
	[self checkFontHasTraits: NSFontBoldTrait withLongestEffectiveRange: NSMakeRange(0, 1) inAttributedString: as];
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(1, 1) inAttributedString: as];
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 2]]];
}

- (void) testInsertCharacters
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"()"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 2)];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"test"];
	
	UKObjectsEqual(@"(test)", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 6) inAttributedString: as];
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 2],
								 [EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 0) changeInLength: 4]]];
}

- (void) testReplaceCharacters
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"()"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(0, 2)];
	[as replaceCharactersInRange: NSMakeRange(1, 1) withString: @">"];
	
	UKObjectsEqual(@"(>", [as string]);
	[self checkAttribute: NSUnderlineStyleAttributeName hasValue: @(NSUnderlineStyleSingle) withLongestEffectiveRange: NSMakeRange(0, 2) inAttributedString: as];
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 2],
								 [EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 1) changeInLength: 0]]];
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

- (void) testInsertInEmptyString
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	UKObjectsEqual(@"a", [as string]);
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1]]];
}

- (void) testInsertAtEndOfString
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
	
	UKObjectsEqual(@"ab", [as string]);
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1],
								 [EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 0) changeInLength: 1]]];
}

- (void) testInsertAfterTwoChunks
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
	[as addAttribute: NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range: NSMakeRange(1, 1)];
	[as replaceCharactersInRange: NSMakeRange(2, 0) withString: @"c"];
	
	UKObjectsEqual(@"abc", [as string]);
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1],
								 [EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 0) changeInLength: 1],
								 [EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(2, 0) changeInLength: 1]]];

}

- (void) testLongestEffectiveRange
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	NSRange longestEffectiveRange;
	id value = [as attribute: @"foo"
					 atIndex: 0
	   longestEffectiveRange: &longestEffectiveRange
					 inRange: NSMakeRange(0, 1)];
	
	UKNil(value);
	UKIntsEqual(0, longestEffectiveRange.location);
	UKIntsEqual(1, longestEffectiveRange.length);
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1]]];

}

- (void) testAttributeAtIndex
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	[as setAttributes: @{ NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle) } range: NSMakeRange(0, 1)];
	
	NSRange effectiveRange;
	UKObjectsEqual(@(NSUnderlineStyleSingle), [as attribute: NSUnderlineStyleAttributeName atIndex: 0 effectiveRange: &effectiveRange]);
	UKRaisesException([as attribute: @"foo" atIndex: 1 effectiveRange: &effectiveRange]);
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1]]];

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
	
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1]]];
}

- (void) testNonExistentAttributeAtEnd
{
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
	
	NSRange effectiveRange;
	UKRaisesException([as attribute: NSUnderlineStyleAttributeName atIndex: 1 effectiveRange: &effectiveRange]);

	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1]]];
}

- (void) testReadAttributeInEmptyString
{
	NSRange effectiveRange;
	UKRaisesException([as attribute: NSUnderlineStyleAttributeName atIndex: 0 effectiveRange: &effectiveRange]);
}

- (void) testEraseAndAdd
{
	// Add "<b>1</b>23"
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"1"];
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"2"];
	[as replaceCharactersInRange: NSMakeRange(2, 0) withString: @"3"];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0, 1) inTextStorage: as];
	UKObjectsEqual(@"123", [as string]);
	
	// Erase it
	[as replaceCharactersInRange: NSMakeRange(0, [as length]) withString: @""];
	UKObjectsEqual(@"", [as string]);
	
	// Add "x"
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"x"];
	UKObjectsEqual(@"x", [as string]);
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
	[self appendString: @"abc" htmlCode: nil toAttributedString: [objectGraph rootObject]];
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 3]]];
	
	((COAttributedStringChunk *)attributedString.chunks[0]).text = @"ac";
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 1) changeInLength: -1]]];

	((COAttributedStringChunk *)attributedString.chunks[0]).text = @"abc";
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 0) changeInLength: 1]]];
}

- (void) testTypeSingleCharacter
{
	// Set up a clone of objectGraph, type a single character in it
	COObjectGraphContext *remoteCtx = [COObjectGraphContext new];
	[remoteCtx setItemGraph: objectGraph];
	[self appendString: @"x" htmlCode: nil toAttributedString: [remoteCtx rootObject]];
	
	// Replicate that change to objectGraph
	[objectGraph setItemGraph: remoteCtx];
#if 0
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 1]]];
#endif
}

- (void) testBoldingSingleCharacter
{
	[self appendString: @"abc" htmlCode: nil toAttributedString: attributedString];
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 3]]];
	
	// Set up a clone of objectGraph, and make the "c" bold
	COObjectGraphContext *remoteCtx = [COObjectGraphContext new];
	[remoteCtx setItemGraph: objectGraph];
	COAttributedStringWrapper *remoteCtxWrapper = [[COAttributedStringWrapper alloc] initWithBacking: [remoteCtx rootObject]];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(2, 1) inTextStorage: remoteCtxWrapper];
	
	// Replicate that change to objectGraph
	[objectGraph setItemGraph: remoteCtx];
#if 0
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedAttributes range: NSMakeRange(2, 1) changeInLength: 0]]];
#endif
}

- (void) testTypeTwoCharactersAndRevert
{
	// 'x'
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"x"];
	[objectGraph acceptAllChanges];
	UKObjectsEqual(@"x", [as string]);
	
	// Create snapshot1 from objectGraph
	COObjectGraphContext *snapshot1 = [COObjectGraphContext new];
	[snapshot1 setItemGraph: objectGraph];

	// 'xy'
	[as replaceCharactersInRange: NSMakeRange(1, 0) withString: @"y"];
	[objectGraph acceptAllChanges];
	UKObjectsEqual(@"xy", [as string]);
	
	// restore to snapshot1
	[(COAttributedStringWrapperTestExtensions *)as clearEditCalls];
	[objectGraph setItemGraph: snapshot1];
	UKObjectsEqual(@"x", [as string]);
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 1) changeInLength: -1]]];
	
	UKDoesNotRaiseException([tv dataWithPDFInsideRect: NSMakeRect(0, 0, 100, 100)]);
}

- (void) testDeleteMultipleChunks
{
	// 'a<b>b</b><i>c</i>'
	[as replaceCharactersInRange: NSMakeRange(0, 0) withString: @"abc"];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(1,1) inTextStorage:as];
	[self setFontTraits: NSFontItalicTrait inRange: NSMakeRange(2,1) inTextStorage:as];
	[objectGraph acceptAllChanges];
		
	// Create branch1 from objectGraph
	COObjectGraphContext *branch1 = [COObjectGraphContext new];
	[branch1 setItemGraph: objectGraph];
	// Erase '<b>b</b><i>c</i>' in the snapshot, append '<u>d</u>'
	[[branch1 rootObject] setChunks: @[[[[branch1 rootObject] chunks] firstObject]]];
	[self appendString: @"d" htmlCode: @"u" toAttributedString: [branch1 rootObject]];
	
	// revert objectGraph to branch1
	[(COAttributedStringWrapperTestExtensions *)as clearEditCalls];
	[objectGraph setItemGraph: branch1];
	UKObjectsEqual(@"ad", [as string]);
#if 0
	[self checkCharacterEdits: @[[EditedCall edited: NSTextStorageEditedCharacters range: NSMakeRange(1, 2) changeInLength: -2]]];
#endif
	
	UKDoesNotRaiseException([tv dataWithPDFInsideRect: NSMakeRect(0, 0, 100, 100)]);
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
