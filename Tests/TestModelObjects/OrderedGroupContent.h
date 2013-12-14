/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * Test model object to be inserted as content in OrderedGroupWithOpposite
 */
@interface OrderedGroupContent : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *parentGroups;
@end