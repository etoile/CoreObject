/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COAttributedString.h"
#import "COAttributedStringDiff.h"
#import "COAttributedStringWrapper.h"
#include "diff.h"

// FIXME: Hack to get -insertObjects:atIndexes:hints:forProperty:
#import "COObject+Private.h"

@implementation COAttributedStringDiff

@synthesize operations = _operations;

static bool arraycomparefn(size_t i, size_t j, const void *userdata1, const void *userdata2)
{
	return [(__bridge NSString *)userdata1 characterAtIndex: i]
	== [(__bridge NSString *)userdata2 characterAtIndex: j];
}
	
- (instancetype) initWithFirstAttributedString: (COAttributedString *)first
						secondAttributedString: (COAttributedString *)second
										source: (id)source
{
	SUPERINIT;
	
	_first = first;
	_second = second;
	_source = source;
	_operations = [NSMutableArray new];
	
	NSString *firstString = [[[COAttributedStringWrapper alloc] initWithBacking: _first] string];
	NSString *secondString = [[[COAttributedStringWrapper alloc] initWithBacking: _second] string];
	
	diffresult_t *result = diff_arrays([firstString length], [secondString length], arraycomparefn, (__bridge void *)firstString, (__bridge void *)secondString);
	
	for (size_t i = 0; i < diff_editcount(result); i++)
	{
		const diffedit_t edit = diff_edit_at_index(result, i);
		const NSRange rangeInA = NSMakeRange(edit.range_in_a.location, edit.range_in_a.length);
		const NSRange rangeInB = NSMakeRange(edit.range_in_b.location, edit.range_in_b.length);
		
		switch (edit.type)
		{
			case difftype_insertion:
				[self recordInsertionRangeA: rangeInA rangeB: rangeInB];
				break;
			case difftype_deletion:
				[self recordDeletionRangeA: rangeInA rangeB: rangeInB];
				break;
			case difftype_modification:
				[self recordModificationRangeA: rangeInA rangeB: rangeInB];
				break;
			case difftype_copy:
				[self recordCopyRangeA: rangeInA rangeB: rangeInB];
				break;
		}
	}
	
	diff_free(result);
	
	return self;
}

- (void) recordInsertionRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	COItemGraph *graph = [_second substringItemGraphWithRange: rangeInB];
	
	COAttributedStringDiffOperationInsertAttributedSubstring *op = [COAttributedStringDiffOperationInsertAttributedSubstring new];
	op.range = rangeInA;
	op.source = _source;
	op.attributedStringItemGraph = graph;
	
	[_operations addObject: op];
}

- (void) recordDeletionRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	COAttributedStringDiffOperationDeleteRange *op = [COAttributedStringDiffOperationDeleteRange new];
	op.range = rangeInA;
	op.source = _source;
	
	[_operations addObject: op];
}

- (void) recordModificationRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	// The semantics of "modification" are that the old and new
	// block are totally unrelated. Thus the old and new attributes
	// are totally semantically unrelated, so we just record it in the diff as
	// 'replace this range with this new attributed string'
	
	COItemGraph *graph = [_second substringItemGraphWithRange: rangeInB];
	
	COAttributedStringDiffOperationReplaceRange *op = [COAttributedStringDiffOperationReplaceRange new];
	op.range = rangeInA;
	op.source = _source;
	op.attributedStringItemGraph = graph;
	
	[_operations addObject: op];
}

- (void) recordCopyRangeA: (NSRange)rangeInA rangeB: (NSRange)rangeInB
{
	// The textual content of these regions is unchanged. Iterate
	// through the attributes and see if they are the same too.
	
	assert(rangeInA.length == rangeInB.length);
	
	// FIXME: Implement
}

#pragma mark - Diff Application

- (void) applyToAttributedString: (COAttributedString *)target
{
	NSInteger i = 0;
	for (id<COAttributedStringDiffOperation> op in self.operations)
	{
		NSLog(@"Applying %@", op);
	
		i += [op applyOperationToAttributedString: target withOffset: i];
	}
}

@end

#pragma mark - Operation Classes

@implementation COAttributedStringDiffOperationInsertAttributedSubstring
@synthesize range, source, attributedStringItemGraph;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	COObjectGraphContext *targetCtx = [target objectGraphContext];
	const NSInteger insertionPos = range.location + offset;
	
	NSUInteger chunkIndex = 0, chunkStart = 0;
	COAttributedStringChunk *chunk = [target chunkContainingIndex: insertionPos chunkStart: &chunkStart chunkIndex: &chunkIndex];
	
	[targetCtx insertOrUpdateItems: [attributedStringItemGraph items]];
	
	COAttributedString *sourceString = [targetCtx loadedObjectForUUID: [attributedStringItemGraph rootItemUUID]];
	
	if (chunk == nil)
	{
		// Inserting at the end of the string
		ETAssert(insertionPos == [target length]);
	}
	else if (insertionPos == chunkStart)
	{
		// Inserting to the left of 'chunk'
		
	}
	else
	{
		// We need to split 'chunk'
		
		ETAssert(insertionPos > chunkStart);
		
		NSUInteger leftChunkLength = insertionPos - chunkStart;
		NSString *leftString = [chunk.text substringToIndex: leftChunkLength];
		NSString *rightString = [chunk.text substringFromIndex: leftChunkLength];
		
		// First, trim 'chunk' down to the point where we are splitting it
		
		chunk.text = leftString;
		
		// Create a new chunk for the right side, copying from the left side so we also copy the
		// attributes.
		// FIXME: Since attributes aren't referred to with a composite rel'n, currently
		// they are being aliased and not copied.
		
		COCopier *copier = [COCopier new];
		ETUUID *rightChunkUUID = [copier copyItemWithUUID: [chunk UUID] fromGraph: targetCtx toGraph: targetCtx];
		COAttributedStringChunk *rightChunk = [targetCtx loadedObjectForUUID: rightChunkUUID];
		rightChunk.text = rightString;

		// Insert the chunks we need to insert
		
		// FIXME: Why is -insertObjects:atIndexes:hints:forProperty: private?!
		[target insertObjects: sourceString.chunks
					atIndexes: [[NSIndexSet alloc] initWithIndexesInRange: NSMakeRange(chunkIndex + 1, [sourceString.chunks count])]
						hints: nil
				  forProperty: @"chunks"];
		
		// Insert rightChunk
		
		[target insertObjects: @[rightChunk]
					atIndexes: [[NSIndexSet alloc] initWithIndex: chunkIndex + 1 + [sourceString.chunks count]]
						hints: nil
				  forProperty: @"chunks"];
		
		return [sourceString length];
	}
	
	return 0;
}

@end

@implementation COAttributedStringDiffOperationDeleteRange
@synthesize range, source;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	return -range.length;
}

@end

@implementation COAttributedStringDiffOperationReplaceRange
@synthesize range, source, attributedStringItemGraph;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	return 0;
}

@end

@implementation COAttributedStringDiffOperationAddAttribute
@synthesize range, source, attributeItemGraph;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	return 0;
}

@end

@implementation COAttributedStringDiffOperationRemoveAttribute
@synthesize range, source, attributeItemGraph;

- (NSInteger) applyOperationToAttributedString: (COAttributedString *)target withOffset: (NSInteger)offset
{
	return 0;
}

@end
