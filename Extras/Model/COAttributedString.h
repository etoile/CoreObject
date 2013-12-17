/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COAttributedString : COObject
@property (nonatomic, readwrite, strong) NSArray *chunks;
@end
