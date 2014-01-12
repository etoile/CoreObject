/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedStringWrapper.h"
#import "COAttributedString.h"
#import "COAttributedStringChunk.h"
#import "COAttributedStringAttribute.h"

@interface COAttributedStringWrapper () <CODiffArraysDelegate>

@end

@implementation COAttributedStringWrapper

@synthesize backing = _backing;

- (instancetype) initWithBacking: (COAttributedString *)aBacking
{
	NILARG_EXCEPTION_TEST(aBacking);
	
	SUPERINIT;
	_lastNotifiedLength = [aBacking length];
	_backing = aBacking;
	_cachedString = [aBacking string];
		
	[_backing addObserver: self forKeyPath: @"chunks" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
	for (COAttributedStringChunk *chunk in _backing.chunks)
	{
		[chunk addObserver: self forKeyPath: @"text" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
		[chunk addObserver: self forKeyPath: @"attributes" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextObjectsDidChangeNotification:)
												 name: COObjectGraphContextObjectsDidChangeNotification
											   object: aBacking.objectGraphContext];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextWillRelinquishObjectsNotification:)
												 name: COObjectGraphContextWillRelinquishObjectsNotification
											   object: aBacking.objectGraphContext];

	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextBeginBatchChangeNotification:)
												 name: COObjectGraphContextBeginBatchChangeNotification
											   object: aBacking.objectGraphContext];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextEndBatchChangeNotification:)
												 name: COObjectGraphContextEndBatchChangeNotification
											   object: aBacking.objectGraphContext];
	
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	for (COObject *object in [_backing.objectGraphContext loadedObjects])
	{
		[self unregisterAsObserverOf: object];
	}
}

// Optimisation
- (void) objectGraphContextBeginBatchChangeNotification: (NSNotification *)notif
{
	[self beginEditing];
}

// Optimisation
- (void) objectGraphContextEndBatchChangeNotification: (NSNotification *)notif
{
	[self endEditing];
}

static void LengthOfCommonPrefixAndSuffix(NSString *a, NSString *b, NSUInteger *prefixOut, NSUInteger *suffixOut)
{
	const NSUInteger alen = [a length];
	const NSUInteger blen = [b length];
	
	NSUInteger i;
	
	for (i = 0; i < MIN(alen, blen); i++)
	{
		if ([a characterAtIndex: i] != [b characterAtIndex: i])
			break;
	}

	*prefixOut = i;
	
	NSUInteger j;
	
	for (j = 0; j < MIN(alen - i, blen - i); j++)
	{
		if ([a characterAtIndex: [a length] - 1 - j] != [b characterAtIndex: [b length] - 1 - j])
			break;
	}

	*suffixOut = j;
}

// These three methods are called by -observeValueForKeyPath:...

- (void)recordInsertionWithLocation: (NSUInteger)aLocation
					insertedObjects: (id)anArray
						   userInfo: (id)info
{
	NSRange characterRange = {[(COAttributedStringChunk *)anArray[0] characterIndex], 0};
	NSUInteger lengthDelta = 0;
	for (COAttributedStringChunk *insertedChunk in anArray)
	{
		ETAssert(insertedChunk.parentString == _backing);
		lengthDelta += insertedChunk.length;
	}
	
	[self edited: NSTextStorageEditedCharacters range: characterRange changeInLength: lengthDelta];
}

- (void)recordDeletionWithRange: (NSRange)aRange
					   userInfo: (id)info
{
	NSArray *oldArray = info;
	NSArray *deletedChunks = [oldArray subarrayWithRange: aRange];
	
	NSInteger deletedChunksLength = 0;
	for (COAttributedStringChunk *deletedChunk in deletedChunks)
	{
		deletedChunksLength += deletedChunk.length;
	}
	
	// UGLY: The deleted character range would start at deletedChunk[aRange.location]'s character index.
	// But since it's a deleted chunk, it's no longer in the chunks array, so we can't ask it for its starting
	// character index.
	NSRange characterRange = {0, deletedChunksLength};
	if (aRange.location > 0)
	{
		COAttributedStringChunk *chunkBeforeDeletedChunk = oldArray[aRange.location - 1];
		ETAssert(chunkBeforeDeletedChunk.parentString == _backing);
		characterRange.location = NSMaxRange([chunkBeforeDeletedChunk characterRange]);
	}
	
	[self edited: NSTextStorageEditedCharacters range: characterRange changeInLength: -deletedChunksLength];
}

- (void)recordModificationWithRange: (NSRange)aRange
					insertedObjects: (id)anArray
						   userInfo: (id)info
{
	NSArray *oldArray = info;
	NSArray *deletedChunks = [oldArray subarrayWithRange: aRange];
	
	NSInteger deletedChunksLength = 0;
	for (COAttributedStringChunk *deletedChunk in deletedChunks)
	{
		deletedChunksLength += deletedChunk.length;
	}
		
	NSInteger insertedChunksLength = 0;
	for (COAttributedStringChunk *insertedChunk in anArray)
	{
		ETAssert(insertedChunk.parentString == _backing);
		insertedChunksLength += insertedChunk.length;
	}
	
	NSRange characterRange = {0, deletedChunksLength};
	if (aRange.location > 0)
	{
		COAttributedStringChunk *chunkBeforeDeletedChunk = oldArray[aRange.location - 1];
		ETAssert(chunkBeforeDeletedChunk.parentString == _backing);
		characterRange.location = NSMaxRange([chunkBeforeDeletedChunk characterRange]);
	}
	
	NSInteger delta = insertedChunksLength - deletedChunksLength;
	
	[self edited: NSTextStorageEditedCharacters range: characterRange changeInLength: delta];
	
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// First,set up KVO for any inserted chunks
	
	if ([keyPath isEqualToString: @"chunks"])
	{
		NSArray *oldArray = change[NSKeyValueChangeOldKey];
		NSArray *newArray = change[NSKeyValueChangeNewKey];
		
		NSMutableSet *newChunks = [NSMutableSet setWithSet: [NSSet setWithArray: newArray]];
		[newChunks minusSet: [NSSet setWithArray: oldArray]];
		
		NSLog(@"%@: New chunks: %@", object, newChunks);
		
		// Set up observation for the new chunks
		
		for (COAttributedStringChunk *chunk in newChunks)
		{
			[chunk addObserver: self forKeyPath: @"text" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
			[chunk addObserver: self forKeyPath: @"attributes" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
		}
	}
	
	if (_inPrimitiveMethod)
		return;
	
	_cachedString = [_backing string];
	
	if ([keyPath isEqualToString: @"chunks"])
	{
		NSArray *oldArray = change[NSKeyValueChangeOldKey];
		NSArray *newArray = change[NSKeyValueChangeNewKey];

		// Handle characters inserted/removed. See -record... methods above
		
		[self beginEditing];
		CODiffArrays(oldArray, newArray, self, oldArray);
		[self endEditing];
	}
	else if ([keyPath isEqualToString: @"text"])
	{
		NSLog(@"%@: Text changed from %@ to %@", object, change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
		
		COAttributedStringChunk *chunk = object;
		NSString *oldText = change[NSKeyValueChangeOldKey];
		
		if ((id)oldText == (id)[NSNull null])
		{
			oldText = @"";
		}
		
		NSString *newText = change[NSKeyValueChangeNewKey];
		NSInteger lengthDelta = (NSInteger)[newText length] - (NSInteger)[oldText length];
		
		// Only pay attention if the chunk is attached to the string we are watching
		if (chunk.parentString == _backing)
		{
			NSRange chunkRange = chunk.characterRange;
			
			NSRange modifiedRange = NSMakeRange(chunkRange.location, oldText.length);
			
			// Optimisation: chop off common prefix and suffix
			
			NSUInteger commonPrefix, commonSuffix;
			LengthOfCommonPrefixAndSuffix(oldText, newText, &commonPrefix, &commonSuffix);
			
			modifiedRange.location += commonPrefix;
			modifiedRange.length -= (commonPrefix + commonSuffix);
			
			[self edited: NSTextStorageEditedCharacters range: modifiedRange changeInLength: lengthDelta];
		}
	}
	else if ([keyPath isEqualToString: @"attributes"])
	{
		
	}
}

- (void) objectGraphContextObjectsDidChangeNotification: (NSNotification *)notif
{
//	_cachedString = [_backing string];
//	
//	if (_inPrimitiveMethod)
//		return;
//	
//	NSUInteger currentLength = [self length];
//	NSInteger delta = (NSInteger)currentLength - _lastNotifiedLength;
//	NSUInteger oldLength = _lastNotifiedLength;
//	_lastNotifiedLength = currentLength;
//	
//	NSLog(@"!!!! COAtrributedString length modified by %d (outside of a NSTextStorage mutation method)", (int)delta);
//		
//	[self edited: NSTextStorageEditedAttributes | NSTextStorageEditedCharacters
//		   range: NSMakeRange(0, oldLength)
//  changeInLength: delta];
}

- (void) unregisterAsObserverOf: (COObject *)object
{
	// FIXME: We need to keep track of exactly what objects we're observing
	
	if ([object isKindOfClass: [COAttributedString class]])
	{
		@try
		{
			[object removeObserver: self forKeyPath: @"chunks"];
		}
		@catch (NSException *e)
		{
		}
	}
	else if ([object isKindOfClass: [COAttributedStringChunk class]])
	{
		@try
		{
			[object removeObserver: self forKeyPath: @"text"];
		}
		@catch (NSException *e)
		{
		}
		@try
		{
			[object removeObserver: self forKeyPath: @"attributes"];
		}
		@catch (NSException *e)
		{
		}
	}
}

- (void) objectGraphContextWillRelinquishObjectsNotification: (NSNotification *)notif
{
	NSArray *objects = [notif userInfo][CORelinquishedObjectsKey];
	for (COObject *object in objects)
	{
		[self unregisterAsObserverOf: object];
	}
}

// Primitive NSAttributedString methods

- (NSString *)string
{
	return _cachedString;
}

//- (id)attribute:(NSString *)attrName atIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
//{
//	NSLog(@"attribute %@ at Index %d effective range", attrName, (int)location);
//	
//	id result = [super attribute: attrName atIndex: location effectiveRange: range];
//	
//	NSLog(@"returned result: %@ range %@", result, range != NULL ? NSStringFromRange(*range) : nil);
//	
//	return result;
//}
//
//- (id)attribute:(NSString *)attrName atIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit
//{
//	NSLog(@">>>attribute %@ at Index %d longest effective range inRange %@", attrName, (int)location, NSStringFromRange(rangeLimit));
//
//	// HACK:
//	if (NSMaxRange(rangeLimit) > [self length])
//	{
//		rangeLimit.length -= (NSMaxRange(rangeLimit) - [self length]);
//	}
//	
//	id result = [super attribute: attrName atIndex: location longestEffectiveRange: range inRange: rangeLimit];
//	
//	NSLog(@">>>returned result: %@ range %@", result, range != NULL ? NSStringFromRange(*range) : nil);
//	
//	return result;
//}

- (NSDictionary *)attributesAtIndex: (NSUInteger)anIndex effectiveRange: (NSRangePointer)aRangeOut
{
	//NSLog(@"%p (%@) attributesAtIndex %d", self, [self string], (int)anIndex);
	
	_inPrimitiveMethod = YES;
	
	NSUInteger chunkIndex = 0, chunkStart = 0;
	COAttributedStringChunk *target = [self.backing chunkContainingIndex: anIndex chunkStart: &chunkStart chunkIndex: &chunkIndex];
	
	if (target != nil)
	{
		if (aRangeOut != NULL)
		{
			*aRangeOut = NSMakeRange(chunkStart, target.length);
		}
		
		NSMutableDictionary *result = [NSMutableDictionary new];
		
		NSFont *font = [NSFont userFontOfSize: 12];
		
		for (COAttributedStringAttribute *attr in target.attributes)
		{
			if ([attr.htmlCode isEqualToString: @"b"])
			{
				font = [[NSFontManager sharedFontManager] convertFont: font toHaveTrait: NSFontBoldTrait];
			}
			if ([attr.htmlCode isEqualToString: @"i"])
			{
				font = [[NSFontManager sharedFontManager] convertFont: font toHaveTrait: NSFontItalicTrait];
			}
			if ([attr.htmlCode isEqualToString: @"u"])
			{
				result[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
			}
		}
		
		result[NSFontAttributeName] = font;
		
		_inPrimitiveMethod = NO;
		//NSLog(@"     attributesAtIndex %d are '%@', effective range %@", (int)anIndex, result, NSStringFromRange(NSMakeRange(chunkStart, target.length)));
		return result;
	}

	_inPrimitiveMethod = NO;
	
	[NSException raise: NSInvalidArgumentException format: @"Index %u out of bounds", (unsigned)anIndex];
	return nil;
}

// Primitive NSMutableAttributedString methods

- (void)replaceCharactersInRange: (NSRange)aRange withString: (NSString *)aString
{
	//NSLog(@"%p (%@) replaceCharactersInRange %@ with '%@'", self, [self string], NSStringFromRange(aRange), aString);
	
	_inPrimitiveMethod = YES;
		
	NSUInteger chunkIndex = 0, chunkStart = 0;
	COAttributedStringChunk *chunk = [_backing chunkContainingIndex: aRange.location chunkStart: &chunkStart chunkIndex: &chunkIndex];
	
	/* Sepecial case: empty string */
	if ([self length] == 0)
	{
		chunk = [[COAttributedStringChunk alloc] initWithObjectGraphContext: _backing.objectGraphContext];
		chunk.text = @"";
		_backing.chunks = @[chunk];
	}
	
	/* Special case: inserting at end of string */
	if (chunk == nil && aRange.location == [self length])
	{
		ETAssert([self length] > 0);
		chunk = [_backing chunkContainingIndex: aRange.location - 1 chunkStart: &chunkStart chunkIndex: &chunkIndex];
	}
	
	ETAssert(chunk != nil);
	const NSUInteger chunkLength = [[chunk text] length];
	
	const NSUInteger indexInChunk = aRange.location - chunkStart;
	NSUInteger lengthInChunkToReplace = aRange.length;
	if (indexInChunk + lengthInChunkToReplace > chunkLength)
	{
		lengthInChunkToReplace = chunkLength - indexInChunk;
	}
	
	NSString *newText = [chunk.text stringByReplacingCharactersInRange: NSMakeRange(indexInChunk, lengthInChunkToReplace) withString: aString];
	chunk.text = newText;
	
	NSUInteger remainingLengthToDelete = aRange.length - lengthInChunkToReplace;
	
	while (remainingLengthToDelete > 0)
	{
		// Scan forward through the following chunks, trimming text as needed

		chunk = _backing.chunks[++chunkIndex];

		lengthInChunkToReplace = MIN([[chunk text] length], remainingLengthToDelete);
		chunk.text = [chunk.text stringByReplacingCharactersInRange: NSMakeRange(0, lengthInChunkToReplace) withString: @""];
		remainingLengthToDelete -= lengthInChunkToReplace;
	}
	
	// TODO: Add tests that check for this
	const NSInteger delta = [aString length] - aRange.length;
	_cachedString = [_backing string];
	[self edited: NSTextStorageEditedCharacters range: aRange changeInLength: delta];
	_lastNotifiedLength += delta;
	
	_inPrimitiveMethod = NO;
}

- (COAttributedStringAttribute *) makeAttr: (NSString *)htmlCode
{
	COAttributedStringAttribute *attribute = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: [_backing objectGraphContext]];
	attribute.htmlCode = htmlCode;
	return attribute;
}

- (NSSet *) ourAttributesForAttributeDict: (NSDictionary *)attrs
{
	NSMutableSet *newAttribs = [NSMutableSet new];
	
	for (NSString *attributeName in attrs)
	{
		id attributeValue = attrs[attributeName];
		
		if ([attributeName isEqual: NSUnderlineStyleAttributeName] && [attributeValue isEqual: @(NSUnderlineStyleSingle)])
		{
			[newAttribs addObject: [self makeAttr: @"u"]];
		}
		else if ([attributeName isEqual: NSFontAttributeName])
		{
			NSFont *font = attributeValue;
			NSFontSymbolicTraits traits = [[font fontDescriptor] symbolicTraits];
			if ((traits & NSFontBoldTrait) == NSFontBoldTrait)
			{
				[newAttribs addObject: [self makeAttr: @"b"]];
			}
			if ((traits & NSFontItalicTrait) == NSFontItalicTrait)
			{
				[newAttribs addObject: [self makeAttr: @"i"]];
			}
		}
	}

	return newAttribs;
}

- (void)setAttributes:(NSDictionary *)attrs forChunk: (COAttributedStringChunk *)aChunk
{
	aChunk.attributes = [self ourAttributesForAttributeDict: attrs];
}

- (void)setAttributes: (NSDictionary *)aDict range: (NSRange)aRange
{
	//NSLog(@"%p (%@) Set attributes %@ range %@", self, [self string], aDict, NSStringFromRange(aRange));
	
	if (aRange.length == 0)
	{
		return;
	}
	
	_inPrimitiveMethod = YES;
	
	// Short-circuit
	{
		NSUInteger chunkIndex = 0, chunkStart = 0;
		COAttributedStringChunk *target = [self.backing chunkContainingIndex: aRange.location chunkStart: &chunkStart chunkIndex: &chunkIndex];

		if (chunkStart <= aRange.location
			&& (chunkStart + target.length) >= NSMaxRange(aRange))
		{
			NSSet *existingAttribs = target.attributes;
			NSSet *proposedAttribs = [self ourAttributesForAttributeDict: aDict];
			
			if ([existingAttribs isEqual: proposedAttribs])
			{
				[self edited: NSTextStorageEditedAttributes range: aRange changeInLength: 0];
				_inPrimitiveMethod = NO;
				return;
			}
		}
	}
		
	const NSUInteger splitChunk1 = [_backing splitChunkAtIndex: aRange.location];
	const NSUInteger splitChunk2 = [_backing splitChunkAtIndex: NSMaxRange(aRange)];
	
	ETAssert(splitChunk2 > splitChunk1);
	
	// Set all chunks from splitChunk1, up to but not including splitChunk2, to
	// have the attributes in aDict
	
	for (NSUInteger i = splitChunk1; i < splitChunk2; i++)
	{
		COAttributedStringChunk *chunk = _backing.chunks[i];
		[self setAttributes: aDict forChunk: chunk];
	}
	
	// TODO: Add tests that check for this
	[self edited: NSTextStorageEditedAttributes range: aRange changeInLength: 0];
	
	_inPrimitiveMethod = NO;
}

- (void) beginEditing
{
	NSLog(@"->> beginEditing");
	[super beginEditing];
}

- (void) endEditing
{
	NSLog(@"<<- endEditing");
	[super endEditing];
}


@end
