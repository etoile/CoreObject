/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * Test model object that has an ordered many-to-many relationship to COObject
 */
@interface OrderedGroupNoOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;

+ (NSUInteger) countOfDeallocCalls;

@end
