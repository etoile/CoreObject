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

/**
 * Converts "setFoo:" to "foo".
 *
 * Preconditions:
 *  - setterlen is strlen(setter)
 *  - strlen(setter) >= 4
 *  - prop has room for (strlen(setter) - 3) bytes
 */
void SetterToProperty(const char *setter, size_t setterlen, char *prop)
{
    memcpy(prop, setter + 3, setterlen - 4);
    prop[0] = tolower(prop[0]);
    prop[setterlen - 4] = '\0';
}

/**
 * Returns YES if the string matches "setXXX:" for some nonempty XXX.
 * Otherwise, returns NO.
 */
BOOL IsSetter(const char *selname, size_t sellen)
{
    return sellen > 4 && memcmp("set", selname, 3) == 0 && selname[sellen - 1] == ':';
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

    const char *selname = sel_getName(theCmd);
    size_t sellen = strlen(selname);
    char propname[sellen];
    
    if (sellen < 4)
    {
        return;
    }
    
    SetterToProperty(selname, sellen, propname);
    
    NSString *key = @(propname);

	[self willChangeValueForProperty: key];
	[self setValue: value forVariableStorageKey: key];
	[self didChangeValueForProperty: key];
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    //NSLog(@"Resolving %@", NSStringFromSelector(sel));
    
    const char *selname = sel_getName(sel);
    const size_t sellen = strlen(selname);
    const BOOL isSetter = IsSetter(selname, sellen);
    
    // Get the property name
    
    char propname[sellen + 1];
    if (isSetter)
    {
        SetterToProperty(selname, sellen, propname);
    }
    else
    {
        memcpy(propname, selname, sellen + 1);
		assert(propname[sellen] == '\0');
    }
    
    // Get the property
    
    objc_property_t property = class_getProperty(self, propname);
    if (property != NULL)
    {
        const char *attributes = property_getAttributes(property);
        BOOL isDynamic = (strchr(attributes, 'D') != NULL);
        
        // FIXME: Check other property attributes are correct e.g. readwrite and not readonly
        if (isDynamic == NO)
            return NO;
        
        if (!isSetter)
        {
            class_addMethod(self, sel, (IMP)&genericGetter, "@@:");
            return YES;
        }
        else
        {
            class_addMethod(self, sel, (IMP)&genericSetter, "v@:@");
            return YES;
        }
    }
    return NO;
}

@end
