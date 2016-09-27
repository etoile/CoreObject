/*
    Copyright (C) 2013 Quentin Mathe

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import "COPersistentObjectContext.h"

@implementation NSObject (COPersistentObjectContext)

- (BOOL)isEditingContext
{
    return NO;
}

- (BOOL)isPersistentRoot
{
    return NO;
}

- (BOOL)isObjectGraphContext
{
    return NO;
}

@end
