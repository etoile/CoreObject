/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class Child;

/**
 * Parent/Child are a simple test case for compsite univalued relationships.
 */
@interface Parent : COObject

@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) Child *child;

@end
