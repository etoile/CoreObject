/*
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface KeyedRelationshipModel : COObject
@property (nonatomic, readwrite, copy) NSDictionary *entries;
@end
