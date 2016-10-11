/*
    Copyright (C) 2014 Quentin Mathe

    Date:  May 2014
    License:  MIT  (see COPYING)
 */

#import "COClassToString.h"
#include <objc/runtime.h>

@implementation COClassToString

+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue: (id)value
{
    if (value == Nil)
        return nil;

    const BOOL isClass = ([value class] == value);
    NSParameterAssert(isClass && !class_isMetaClass(value));

    return NSStringFromClass(value);
}

- (id)reverseTransformedValue: (id)value
{
    if (value == nil)
        return Nil;

    NSParameterAssert([value isKindOfClass: [NSString class]]);

    Class class = NSClassFromString(value);
    ETAssert(class != Nil);
    ETAssert([NSStringFromClass(class) isEqual: value]);
    return class;
}

@end
