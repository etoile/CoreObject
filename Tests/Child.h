/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class Parent;

@interface Child : COObject

@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, weak, nonatomic) Parent *parent;

@end
