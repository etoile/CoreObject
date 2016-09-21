/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class Parent;

@interface Child : COObject

@property (nonatomic, readwrite, copy) NSString *label;
@property (nonatomic, readwrite, weak) Parent *parent;

@end
