/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COBezierPath : COObject
@property (nonatomic, readwrite, copy) NSArray *nodes;
@end
