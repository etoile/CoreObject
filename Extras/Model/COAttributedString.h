/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

/**
 * Behaviour of COAttributedString:
 *
 * - merge: " .. the worst ... " -----> " ... _the worst_ ... " (underline)
 *                                \
 *                                 \--> " ... the very worst ... " (insert "very")
 *   merge result is:
 *   " ... _the very worst_ ... " (very is underlined)
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

@end
