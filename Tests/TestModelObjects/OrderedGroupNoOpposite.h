/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * Test model object that has an ordered many-to-many relationship to COObject
 */
@interface OrderedGroupNoOpposite: COObject
@property (nonatomic, readwrite, strong) NSString *label;
@property (nonatomic, readwrite, strong) NSArray *contents;

+ (NSUInteger) countOfDeallocCalls;

@end
