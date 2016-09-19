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

- (instancetype) initWithBacking: (COAttributedString *)aBacking
{
	NILARG_EXCEPTION_TEST(aBacking);
	
	SUPERINIT;
	_observedObjectsSet = [NSHashTable hashTableWithOptions: NSPointerFunctionsObjectPointerPersonality | NSHashTableStrongMemory];
	
	self.backing = aBacking;
	
	return self;
}

- (instancetype)init
{
	return [self initWithBacking: nil];
}

- (void) registerToObserveBacking
{
	[_observedObjectsSet addObject: _backing];
	[_backing addObserver: self forKeyPath: @"chunks" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
	for (COAttributedStringChunk *chunk in _backing.chunks)
	{
		[_observedObjectsSet addObject: chunk];
		[chunk addObserver: self forKeyPath: @"text" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
		[chunk addObserver: self forKeyPath: @"attributes" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextObjectsDidChangeNotification:)
												 name: COObjectGraphContextObjectsDidChangeNotification
											   object: _backing.objectGraphContext];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextWillRelinquishObjectsNotification:)
												 name: COObjectGraphContextWillRelinquishObjectsNotification
											   object: _backing.objectGraphContext];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextBeginBatchChangeNotification:)
												 name: COObjectGraphContextBeginBatchChangeNotification
											   object: _backing.objectGraphContext];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextEndBatchChangeNotification:)
												 name: COObjectGraphContextEndBatchChangeNotification
											   object: _backing.objectGraphContext];
}

- (void) unregisterToObserveBacking
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	for (COObject *object in [_observedObjectsSet copy])
	{
		[self unregisterAsObserverOf: object];
	}

	ETAssert([_observedObjectsSet count] == 0);
}

- (COAttributedString *)backing
{
	return _backing;
}

- (void)setBacking:(COAttributedString *)backing
{
	_lastNotifiedLength = backing.length;
	_cachedString = [backing string];
	
	[self unregisterToObserveBacking];
	_backing = backing;
	[self registerToObserveBacking];
	
	// TODO: Call -edited:...
}

- (void) dealloc
{
	[self unregisterToObserveBacking];
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
	const NSUInteger alen = a.length;
	const NSUInteger blen = b.length;
	
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
		if ([a characterAtIndex: a.length - 1 - j] != [b characterAtIndex: b.length - 1 - j])
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
	BOOL hasAttributes = NO;
	for (COAttributedStringChunk *insertedChunk in anArray)
	{
		ETAssert(insertedChunk.parentString == _backing);
		lengthDelta += insertedChunk.length;
		if (insertedChunk.attributes.count > 0)
		{
			hasAttributes = YES;
		}
	}
	
	if (lengthDelta == 0)
	{
		NSLog(@"Warning, an empty chunk is being inserted");
		return;
	}
	
	NSUInteger mask = NSTextStorageEditedCharacters;
	if (hasAttributes)
		mask = mask | NSTextStorageEditedAttributes;
	
	[self edited: mask range: characterRange changeInLength: lengthDelta];
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
	
	[self edited: NSTextStorageEditedCharacters | NSTextStorageEditedAttributes range: characterRange changeInLength: -deletedChunksLength];
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
	
	[self edited: NSTextStorageEditedCharacters | NSTextStorageEditedAttributes range: characterRange changeInLength: delta];
	
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// First,set up KVO for any inserted chunks
	
	if ([keyPath isEqualToString: @"chunks"])
	{
		NSArray *oldArray = change[NSKeyValueChangeOldKey];
		NSArray *newArray = change[NSKeyValueChangeNewKey];
		
		NSMutableSet *newChunks = [NSMutableSet setWithSet: [NSSet setWithArray: newArray]];
		// N.B.: Objects in these sets are COAttributedStringChunk. The set difference is using
		// pointer equality, this is intended.
		[newChunks minusSet: [NSSet setWithArray: oldArray]];
		
		NSLog(@"%@: New chunks: %@", object, newChunks);
		
		// Set up observation for the new chunks
		// TODO: Could there be a case when we weren't already observing the old chunks?
		
		for (COAttributedStringChunk *chunk in newChunks)
		{
			if ([_observedObjectsSet containsObject: chunk])
			{
				// Don't observe it again!
				continue;
			}
			
			[_observedObjectsSet addObject: chunk];
			[chunk addObserver: self forKeyPath: @"text" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
			[chunk addObserver: self forKeyPath: @"attributes" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
		}
	}
	
	if (_inPrimitiveMethod)
		return;
	
	if ([keyPath isEqualToString: @"chunks"])
	{
		NSArray *oldArray = change[NSKeyValueChangeOldKey];
		NSArray *newArray = change[NSKeyValueChangeNewKey];

		// Handle characters inserted/removed. See -record... methods above
		//
		// This is going to produce overly coarse -edited calls.
		// We should probably do an actual character-by-character diff
		
		[self beginEditing];
		
		// N.B. This used to be above the -beginEditingCall, but that would violate
		// the principle that you can't modify an NSAttributedStringWrapper from
		// outside a -beginEditing/-endEditing block
		_cachedString = [_backing string];
		
		CODiffArrays(oldArray, newArray, self, oldArray);
		[self endEditing];
	}
	else if ([keyPath isEqualToString: @"text"])
	{
		_cachedString = [_backing string];
		
		
		NSLog(@"%@: Text changed from %@ to %@", object, change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
		
		COAttributedStringChunk *chunk = object;
		NSString *oldText = change[NSKeyValueChangeOldKey];
		
		if ((id)oldText == (id)[NSNull null])
		{
			oldText = @"";
		}
		
		NSString *newText = change[NSKeyValueChangeNewKey];
		NSInteger lengthDelta = (NSInteger)newText.length - (NSInteger)oldText.length;
		
		
		if ([oldText isEqualToString: newText])
		{
			return;
		}
		
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
		_cachedString = [_backing string];
		
		
		COAttributedStringChunk *chunk = object;
		ETAssert([chunk isKindOfClass: [COAttributedStringChunk class]]);
		
		if ([change[NSKeyValueChangeOldKey] isEqual: change[NSKeyValueChangeNewKey]])
		{
			return;
		}
		
		[self edited: NSTextStorageEditedAttributes range: [chunk characterRange] changeInLength: 0];
	}
}

- (void) objectGraphContextObjectsDidChangeNotification: (NSNotification *)notif
{
}

- (void) unregisterAsObserverOf: (COObject *)object
{
	if (![_observedObjectsSet containsObject: object])
		return;

	[_observedObjectsSet removeObject: object];
	
	if ([object isKindOfClass: [COAttributedString class]])
	{
		[object removeObserver: self forKeyPath: @"chunks"];
	}
	else if ([object isKindOfClass: [COAttributedStringChunk class]])
	{
		[object removeObserver: self forKeyPath: @"text"];
		[object removeObserver: self forKeyPath: @"attributes"];
	}
}

- (void) objectGraphContextWillRelinquishObjectsNotification: (NSNotification *)notif
{
	NSArray *objects = notif.userInfo[CORelinquishedObjectsKey];
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

/**
 * According to the Apple API doc: "The symbolic traits supersede the existing 
 * NSFontTraitMask type used by NSFontManager. The corresponding values are kept 
 * compatible between NSFontTraitMask and NSFontSymbolicTraits. 
 */
- (NSFont *)convertFont: (NSFont *)font toHaveTrait: (NSFontSymbolicTraits)aTrait
{
#if TARGET_OS_IPHONE
	// NOTE: This code should work on Mac OS X, but -fontWithDescriptor:size: is broken.
	NSFontSymbolicTraits traits = (font.fontDescriptor.symbolicTraits | aTrait);
	NSFontDescriptor *desc = [font.fontDescriptor fontDescriptorWithSymbolicTraits: traits];

	return [NSFont fontWithDescriptor: desc
	                             size: desc.pointSize];
#else
	return [[NSFontManager sharedFontManager] convertFont: font
	                                          toHaveTrait: aTrait];
#endif
}

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
		
#if TARGET_OS_IPHONE
		UIFont *font = [UIFont systemFontOfSize: 12];
#else
		NSFont *font = [NSFont userFontOfSize: 12];
#endif
		for (COAttributedStringAttribute *attr in target.attributes)
		{
			if ([attr.styleKey isEqualToString: @"font-weight"] && [attr.styleValue isEqualToString: @"bold"])
			{
				font = [self convertFont: font toHaveTrait: NSFontBoldTrait];
			}
			if ([attr.styleKey isEqualToString: @"font-style"] && [attr.styleValue isEqualToString: @"oblique"])
			{
				font = [self convertFont: font toHaveTrait: NSFontItalicTrait];
			}
			if ([attr.styleKey isEqualToString: @"text-decoration"] && [attr.styleValue isEqualToString: @"underline"])
			{
				result[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
			}
			if ([attr.styleKey isEqualToString: @"text-decoration"] && [attr.styleValue isEqualToString: @"line-through"])
			{
				result[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
			}
			if ([attr.styleKey isEqualToString: @"color"])
			{
				NSColor *color = [[NSValueTransformer valueTransformerForName: @"COColorToHTMLString"] reverseTransformedValue: attr.styleValue];
				if (color != nil)
				{
					result[NSForegroundColorAttributeName] = color;
				}
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
	const NSUInteger firstChunkIndex = chunkIndex;
	
	/* Sepecial case: empty string */
	if (self.length == 0)
	{
		chunk = [[COAttributedStringChunk alloc] initWithObjectGraphContext: _backing.objectGraphContext];
		chunk.text = @"";
		_backing.chunks = @[chunk];
	}
	
	/* Special case: inserting at end of string */
	if (chunk == nil && aRange.location == self.length)
	{
		ETAssert([self length] > 0);
		chunk = [_backing chunkContainingIndex: aRange.location - 1 chunkStart: &chunkStart chunkIndex: &chunkIndex];
	}
	
	ETAssert(chunk != nil);
	const NSUInteger chunkLength = chunk.text.length;
	
	const NSUInteger indexInChunk = aRange.location - chunkStart;
	NSUInteger lengthInChunkToReplace = aRange.length;
	if (indexInChunk + lengthInChunkToReplace > chunkLength)
	{
		lengthInChunkToReplace = chunkLength - indexInChunk;
	}
	
	NSString *newText = [chunk.text stringByReplacingCharactersInRange: NSMakeRange(indexInChunk, lengthInChunkToReplace) withString: aString];
	chunk.text = newText;
	
	if (newText.length == 0)
	{
		[[_backing mutableArrayValueForKey: @"chunks"] removeObjectAtIndex: chunkIndex--];
	}
	
	NSUInteger remainingLengthToDelete = aRange.length - lengthInChunkToReplace;
	
	while (remainingLengthToDelete > 0)
	{
		// Scan forward through the following chunks, trimming text as needed

		chunk = _backing.chunks[++chunkIndex];

		lengthInChunkToReplace = MIN([[chunk text] length], remainingLengthToDelete);
		chunk.text = [chunk.text stringByReplacingCharactersInRange: NSMakeRange(0, lengthInChunkToReplace) withString: @""];
		remainingLengthToDelete -= lengthInChunkToReplace;
		
		if ((chunk.text).length == 0)
		{
			[[_backing mutableArrayValueForKey: @"chunks"] removeObjectAtIndex: chunkIndex--];
		}
	}
	
	[self mergeChunksInChunkRange: NSMakeRange(firstChunkIndex, chunkIndex + 1 - firstChunkIndex)];
	
	// TODO: Add tests that check for this
	const NSInteger delta = aString.length - aRange.length;
	_cachedString = [_backing string];
	[self edited: NSTextStorageEditedCharacters range: aRange changeInLength: delta];
	_lastNotifiedLength += delta;
	
	_inPrimitiveMethod = NO;
}

- (COAttributedStringAttribute *) makeAttr: (NSString *)key value: (NSString *)value
{
	COAttributedStringAttribute *attribute = [[COAttributedStringAttribute alloc] initWithObjectGraphContext: _backing.objectGraphContext];
	attribute.styleKey = key;
	attribute.styleValue = value;
	return attribute;
}

/**
 * Returns set of COAttributedStringAttribute
 */
- (NSSet *) ourAttributesForAttributeDict: (NSDictionary *)attrs
{
	NSMutableSet *newAttribs = [NSMutableSet new];
	
	for (NSString *attributeName in attrs)
	{
		id attributeValue = attrs[attributeName];
		
		if ([attributeName isEqual: NSUnderlineStyleAttributeName] && [attributeValue intValue] == NSUnderlineStyleSingle)
		{
			[newAttribs addObject: [self makeAttr: @"text-decoration" value: @"underline"]];
		}
		else if ([attributeName isEqual: NSFontAttributeName])
		{
			NSFont *font = attributeValue;
			NSFontSymbolicTraits traits = font.fontDescriptor.symbolicTraits;
			if ((traits & NSFontBoldTrait) == NSFontBoldTrait)
			{
				[newAttribs addObject: [self makeAttr: @"font-weight" value: @"bold"]];
			}
			if ((traits & NSFontItalicTrait) == NSFontItalicTrait)
			{
				[newAttribs addObject: [self makeAttr: @"font-style" value: @"oblique"]];
			}
		}
		else if ([attributeName isEqual: NSStrikethroughStyleAttributeName] && [attributeValue intValue] == NSUnderlineStyleSingle)
		{
			[newAttribs addObject: [self makeAttr: @"text-decoration" value: @"line-through"]];
		}
		else if ([attributeName isEqual: NSForegroundColorAttributeName])
		{
			NSString *colorString = [[NSValueTransformer valueTransformerForName: @"COColorToHTMLString"] transformedValue: attributeValue];
			if (colorString != nil)
			{
				[newAttribs addObject: [self makeAttr: @"color" value: colorString]];
			}
		}
	}

	//NSLog(@">>> Returning %@ for %@", newAttribs, attrs);
	
	return newAttribs;
}

- (void)setAttributes:(NSDictionary *)attrs forChunk: (COAttributedStringChunk *)aChunk
{
	aChunk.attributes = [self ourAttributesForAttributeDict: attrs];
}

- (void)mergeChunksInChunkRange: (NSRange)range
{
	NSMutableArray *chunksProxy = [self.backing mutableArrayValueForKey: @"chunks"];
	
	for (NSUInteger i = range.location; i <= NSMaxRange(range); i++)
	{
		if (i >= chunksProxy.count)
			break;
		
		if (i == 0)
			continue;
		
		COAttributedStringChunk *chunkI = chunksProxy[i];
		COAttributedStringChunk *chunkLeftOfI = chunksProxy[i - 1];
		
		if ([COAttributedStringAttribute isAttributeSet: chunkI.attributes
											 equalToSet: chunkLeftOfI.attributes])
		{
			// we can merge them!
			
			chunkLeftOfI.text = [chunkLeftOfI.text stringByAppendingString: chunkI.text];
			
			[chunksProxy removeObjectAtIndex: i];
			i--; // N.B.: Won't underflow because i > 0 (see if (i == 0) continue; above)
		}
	}
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
			
			if ([COAttributedStringAttribute isAttributeSet: existingAttribs equalToSet: proposedAttribs])
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
	
	[self mergeChunksInChunkRange: NSMakeRange(splitChunk1, splitChunk2 - splitChunk1)];
	
	// TODO: Add tests that check for this
	[self edited: NSTextStorageEditedAttributes range: aRange changeInLength: 0];
	
	_inPrimitiveMethod = NO;
}

#pragma mark - Debugging / Self-checks

- (void) beginEditing
{
	NSLog(@"->> beginEditing");
	
	if (_beginEditingStackDepth == 0)
	{
		_lengthAtStartOfBatch = self.length;
		_lengthDeltaInBatch = 0;
	}
	
	_beginEditingStackDepth++;
	
	[super beginEditing];
}

- (void) endEditing
{
	NSLog(@"<<- endEditing");
	
	_beginEditingStackDepth--;
	
	BOOL reachedZero = (_beginEditingStackDepth == 0);
	
	if (_beginEditingStackDepth < 0)
	{
		[NSException raise: NSInternalInconsistencyException
					format: @"-endEditing called too many times on %@", self];
	}
	
	[super endEditing];
	
	if (reachedZero)
	{
		// Self-check
		
		NSInteger lengthAtEndOfBatch = self.length;
		NSInteger expectedLength = _lengthAtStartOfBatch + _lengthDeltaInBatch;
		
		if (lengthAtEndOfBatch != expectedLength)
		{
			[NSException raise: NSInternalInconsistencyException
						format: @"COAttributedStringWrapper user made incorrect calls to -edited:range:changeInLength:. Expected length %d, actual length at end of batch is %d", (int)expectedLength, (int)lengthAtEndOfBatch];
		}
	}
}

- (void) edited: (NSTextStorageEditActions)editedMask range: (NSRange)range changeInLength: (NSInteger)delta
{
	_lengthDeltaInBatch += delta;
	[super edited: editedMask range: range changeInLength: delta];
}

@end
