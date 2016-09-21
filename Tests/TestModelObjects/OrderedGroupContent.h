/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * Test model object to be inserted as content in OrderedGroupWithOpposite
 */
@interface OrderedGroupContent : COObject
@property (nonatomic, readwrite, copy) NSString *label;
@property (nonatomic, readwrite, copy) NSSet *parentGroups;
@end
