/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

/**
 * Test model object that has an unordered many-to-many relationship to UnorderedGroupContent
 */
@interface UnorderedGroupWithOpposite: COObject
@property (nonatomic, readwrite, copy) NSString *label;
@property (nonatomic, readwrite, copy) NSSet *contents;
@end
