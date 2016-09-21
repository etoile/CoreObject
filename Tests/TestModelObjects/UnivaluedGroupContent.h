/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * Test model object to be inserted as content in UnivaluedGroupWithOpposite
 */
@interface UnivaluedGroupContent : COObject
@property (nonatomic, readwrite, strong) NSString *label;
@property (nonatomic, readwrite, strong) NSSet *parents;
@end
