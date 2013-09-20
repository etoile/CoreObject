/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  September 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COObject.h"
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

static id genericGetter(id theSelf, SEL theCmd)
{
    // FIXME: This is the simplest thing that would work..
    //
    // Variable storage should be changed to an array. This should be
    // rewritten to use a hashmap lookup which maps theCmd to an index in the
    // array.
    
    id result = [theSelf primitiveValueForKey: NSStringFromSelector(theCmd)];
    return result;
}

static void genericSetter(id theSelf, SEL theCmd, id value)
{
    // FIXME: Same comment as the genericGetter
    
    NSString *key = SetterToProperty(NSStringFromSelector(theCmd));
	
    [theSelf setValue: value forPropertyWithoutSetter: key];
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    Class classToCheck = self;
    
    while (classToCheck != Nil)
    {
        unsigned int propertyCount;
        objc_property_t *propertyList = class_copyPropertyList(classToCheck, &propertyCount);
        
        for (unsigned int i=0; i<propertyCount; i++)
        {
            objc_property_t property = propertyList[i];
        
            // FIXME: This portion is a really quick hack; implement properly.
            // Should check that the property is marked @dynamic.
            
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
