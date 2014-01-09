/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COAttributedStringChunk : COObject
@property (nonatomic, readwrite, strong) NSString *text;
@property (nonatomic, readwrite, strong) NSSet *attributes;

/**
 * Returns an item graph that contains a copy of the receiver that has been trimmed to the given subrange as its root object.
 */
- (COItemGraph *) subchunkItemGraphWithRange: (NSRange)aRange;

@property (nonatomic, readonly) NSUInteger length;

/**
 * Returns a string like @"b,u" if the chunk is bold and underlined
 */
- (NSString *) attributesDebugDescription;

@end
