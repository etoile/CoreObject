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
 * Converts "foo" to "setFoo:".
 *
 * Preconditions: 
 *   - setter has room for (5 + strlen(prop)) bytes
 *   - proplen is strlen(prop)
 */
void PropertyToSetter(const char *prop, size_t proplen, char *setter)
{
    setter[0] = 's';
    setter[1] = 'e';
    setter[2] = 't';
    memcpy(setter+3, prop, proplen);
    setter[3] = toupper(setter[3]);
    setter[3+proplen] = ':';
    setter[3+proplen+1] = '\0';
}

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

    const char *setter_cstring = sel_getName(theCmd);
    size_t setter_cstring_len = strlen(setter_cstring);
    char key_cstring[setter_cstring_len];
    
    if (setter_cstring_len < 4)
    {
        return;
    }
    
    SetterToProperty(setter_cstring, setter_cstring_len, key_cstring);
    
    NSString *key = [NSString stringWithUTF8String: key_cstring];

	[self willChangeValueForProperty: key];
	[self setValue: value forVariableStorageKey: key];
	[self didChangeValueForProperty: key];
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    //NSLog(@"Resolving %@", NSStringFromSelector(sel));
    
    const char *selname = sel_getName(sel);
    Class classToCheck = self;

	// FIXME: Don't iterate over all properties but access a single property using class_getProperty()
    while (classToCheck != Nil)
    {
        unsigned int propertyCount;
        objc_property_t *propertyList = class_copyPropertyList(classToCheck, &propertyCount);

        for (unsigned int i=0; i<propertyCount; i++)
        {
            objc_property_t property = propertyList[i];
            const char *attributes = property_getAttributes(property);
            BOOL isDynamic = (strchr(attributes, 'D') != NULL);

            // FIXME: Check other property attributes are correct e.g. readwrite and not readonly
            if (isDynamic == NO)
				continue;

            // TODO: Implement more accessors for performance.
            
            const char *propname = property_getName(property);
            size_t propname_len = strlen(propname);
            char settername[propname_len + 5];
            PropertyToSetter(propname, propname_len, settername);
            
            if (!strcmp(selname, propname))
            {
                class_addMethod(classToCheck, sel, (IMP)&genericGetter, "@@:");
                free(propertyList);
                return YES;
            }
            else if (!strcmp(selname, settername))
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
