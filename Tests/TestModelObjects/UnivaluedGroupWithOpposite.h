/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@class UnivaluedGroupContent;

/**
 * Test model object that has an univalued relationship to UnivaluedGroupContent
 */
@interface UnivaluedGroupWithOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) UnivaluedGroupContent *content;
@end