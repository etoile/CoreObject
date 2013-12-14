/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COBezierPath : COObject
@property (nonatomic, readwrite, strong) NSArray *nodes;
@end
