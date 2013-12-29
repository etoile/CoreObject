/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class COAttributedStringChunk;

/**
 * Behaviour of COAttributedString:
 *
 * - merge: " .. the worst ... " -----> " ... _the worst_ ... " (underline)
 *                                \
 *                                 \--> " ... the very worst ... " (insert "very")
 *   merge result is:
 *   " ... _the very worst_ ... " (very is underlined)
 *
 * - TODO: when pasting, you may want the attributes surrounding the paste 
 *   target to be extended over the pasted text, or not. Make it configurable.
 *
 * - COAttributedStringChunk and COAttributedStringAttribute are private objects...
 *   their UUIDs are irrelevant
 *
 * - attributes are immutable as far as diff is concerned, they can only
 *   be added / removed.
 */
@interface COAttributedString : COObject
@property (nonatomic, readwrite, strong) NSArray *chunks;

- (COItemGraph *) substringItemGraphWithRange: (NSRange)aRange;

/**
 * Returns the chunk containing the given index. 
 * If the index is the end of the string, returns nil.
 * If the index is between two chunks, returns the chunk on the right.
 *
 * If a non-nil chunk is returned, and chunkStartOut is non-NULL, writes the
 * index of the beginning of the returned chunk into chunkStartOut.
 */
- (COAttributedStringChunk *) chunkContainingIndex: (NSUInteger)anIndex chunkStart: (NSUInteger *)chunkStartOut chunkIndex: (NSUInteger *)chunkIndexOut;

@property (nonatomic, readonly, assign) NSUInteger length;

/**
 * Splits the chunk at the given character index. 
 * Returns the _chunk index_ of the split location. 
 * If the given characterIndex is already on a chunk boundary, does nothing.
 */
- (NSUInteger) splitChunkAtIndex: (NSUInteger)characterIndex;

- (NSSet *) attributesSetAtIndex: (NSUInteger)characterIndex longestEffectiveRange: (NSRange *)rangeOut inRange: (NSRange)rangeLimit;

@end
