/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class Child;

/**
 * Parent/Child are a simple test case for compsite univalued relationships.
 */
@interface Parent : COObject

@property (nonatomic, readwrite, strong) NSString *label;
@property (nonatomic, readwrite, strong) Child *child;

@end
