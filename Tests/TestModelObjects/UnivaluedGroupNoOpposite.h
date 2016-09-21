/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"
/**
 * Test model object that has an univalued relationship to COObject (no opposite)
 */
@interface UnivaluedGroupNoOpposite: COObject
@property (nonatomic, readwrite, copy) NSString *label;
@property (nonatomic, readwrite, strong) COObject *content;

+ (NSUInteger) countOfDeallocCalls;

@end
