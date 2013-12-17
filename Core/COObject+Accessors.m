/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import "COObject.h"
#import "COObject+Private.h"
#include <objc/runtime.h>

@interface COObject (Accessors)
@end

@implementation COObject (Accessors)

NSString *PropertyToSetter(NSString *prop)
{
    return [NSString stringWithFormat: @"set%@%@:",
            [[prop substringWithRange: NSMakeRange(0, 1)] uppercaseString],
            [prop substringFromIndex: 1]];
}

NSString *SetterToProperty(NSString *prop)
{
    return [NSString stringWithFormat: @"%@%@",
            [[prop substringWithRange: NSMakeRange(3, 1)] lowercaseString],
            [prop substringWithRange: NSMakeRange(4,  [prop length] - 5)]];
}

static id genericGetter(id self, SEL theCmd)
{
    // FIXME: Variable storage should be changed to an array. This should be
    // rewritten to use a hashmap lookup which maps theCmd to an index in the
    // array.

    return [self valueForVariableStorageKey: NSStringFromSelector(theCmd)];
}

static void genericSetter(id self, SEL theCmd, id value)
{
    // FIXME: Same comment as the genericGetter

    NSString *key = SetterToProperty(NSStringFromSelector(theCmd));

	[self willChangeValueForProperty: key];
	[self setValue: value forVariableStorageKey: key];
	[self didChangeValueForProperty: key];
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    Class classToCheck = self;

	// FIXME: Don't iterate over all properties but access a single property using class_getProperty()
    while (classToCheck != Nil)
    {
        unsigned int propertyCount;
        objc_property_t *propertyList = class_copyPropertyList(classToCheck, &propertyCount);

        for (unsigned int i=0; i<propertyCount; i++)
        {
            objc_property_t property = propertyList[i];
			NSString *attributes = [NSString stringWithUTF8String: property_getAttributes(property)];
			BOOL isDynamic = ([attributes rangeOfString: @"D"].location != NSNotFound);

            // FIXME: Check other property attributes are correct e.g. readwrite and not readonly
            if (isDynamic == NO)
				continue;

            // TODO: Implement more accessors for performance.
            
            NSString *propName = [NSString stringWithUTF8String: property_getName(property)];
            NSString *setterName = PropertyToSetter(propName);
            
            NSString *selName = NSStringFromSelector(sel);
            
            if ([selName isEqual: propName])
            {
                class_addMethod(classToCheck, sel, (IMP)&genericGetter, "@@:");
                free(propertyList);
                return YES;
            }
            else if ([selName isEqual: setterName])
            {
                class_addMethod(classToCheck, sel, (IMP)&genericSetter, "v@:@");
                free(propertyList);
                return YES;
            }
        }
        free(propertyList);
        
        classToCheck = class_getSuperclass(classToCheck);
    }
    return NO;
}

@end
