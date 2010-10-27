#import "NSObject+Mixins.h"
#include <objc/objc.h>
#include <objc/objc-api.h>

static inline BOOL validateMethodTypes(Method_t method1, Method_t method2)
{
	return strcmp(method1->method_types, method2->method_types) == 0;
}

static inline Method_t findMethod(const char* methodName, Class aClass, BOOL searchSuper)
{
	while(aClass != Nil)
	{
		struct objc_method_list * methods = aClass->methods;
		while(methods != NULL)
		{
			for(unsigned int i=0 ; i<methods->method_count ; i++)
			{
				Method_t method = &methods->method_list[i];
				if(strcmp(methodName, sel_get_name(method->method_name)) == 0)
				{
					return method;
				}
			}
			methods = methods->method_next;
		}
		if(searchSuper)
		{
			aClass = aClass->super_class;
		}
		else
		{
			aClass = Nil;
		}
	}
	return NULL;
}

static inline BOOL methodTypesMatch(Class aClass, Class aMixin)
{
	struct objc_method_list * methods = aMixin->methods;
	while(methods != NULL)
	{
		for(unsigned int i=0 ; i<methods->method_count ; i++)
		{
			Method_t method = &methods->method_list[i];
			Method_t oldMethod = findMethod(sel_get_name(method->method_name), aClass, YES);
			/* If there is an existing method with this name, check the types match */
			if(oldMethod != NULL
				&&
				strcmp(method->method_types, oldMethod->method_types) != 0)
			{
				return NO;
			}
		}
		methods = methods->method_next;
	}
	return YES;
}

static inline BOOL iVarTypesMatch(Class aClass, Class aMixin)
{
	struct objc_ivar_list * mixinIVars = aMixin->ivars;
	struct objc_ivar_list * classIVars = aMixin->ivars;
	if(mixinIVars != NULL)
	{
		/* If the mixin has more ivars than the class */
		if(classIVars == NULL
			||
			classIVars->ivar_count < mixinIVars->ivar_count)
		{
			return NO;
		}
		/* Look at each ivar in the mixin */
		for(unsigned int i=0 ; i<mixinIVars->ivar_count ; i++)
		{
			/* If the mixin has ivars of a different type to the class*/
			if(strcmp(mixinIVars->ivar_list[i].ivar_type, classIVars->ivar_list[i].ivar_type) != 0)
			{
				return NO;
			}
		}
	}
	return YES;
}
id test(id self, SEL cmd)
{
	return nil;
}
//Objective-C runtime library private function
void __objc_update_dispatch_table_for_class(Class);

static inline void addMethods(Class aClass, struct objc_method_list * methods)
{
	struct objc_method_list * newMethods = malloc(
			sizeof(struct objc_method_list)
			+
			(methods->method_count * sizeof(struct objc_method)));
	int usedMethods = 0;
	/* We need to copy the entire method list, because otherwise replacing
	 * methods in it will cause us problems later. */
	for(unsigned int i=0 ; i<methods->method_count ; i++)
	{
		Method_t mixinMethod = &methods->method_list[i];
		Method_t oldMethod = findMethod(sel_get_name(mixinMethod->method_name), aClass, NO);
		if(oldMethod != NULL)
		{
			/* Update the old IMP to point to the new method */
			oldMethod->method_imp = mixinMethod->method_imp;
		}
		else
		{
			/* Add the new method to the list */
			memcpy(&newMethods->method_list[usedMethods++], 
					mixinMethod, 
					sizeof(struct objc_method));
		}
	}
	/* Free up any bonus memory we allocated */
	if(usedMethods > 0 
		&&
		methods->method_count < usedMethods)
	{
		newMethods = realloc(newMethods,
			sizeof(struct objc_method_list)
			+
			(usedMethods * sizeof(struct objc_method)));
	}
	/* Add the new method list to the class */
	if(usedMethods > 0)
	{
		newMethods->method_count = usedMethods;
		newMethods->method_next = aClass->methods;
		aClass->methods = newMethods;
	}
	else
	{
		/* Sometimes, all of our methods will be replacing existing ones */
		free(newMethods);
	}
}

static void checkSafeComposition(Class class, Class aClass)
{
	/* Check that the mixin will never try to access ivars from after the end of the 
	 * object */
	if(class->instance_size < aClass->instance_size)
	{
		[NSException raise:@"MixinTooBigException"
		            format:@"Class %@ is smaller than composed class %@.  Instance variables access from mixin is unsafe.", class, aClass];
	}
	if(!iVarTypesMatch(class, aClass))
	{
		[NSException raise:@"MixinIVarTypeMismatchException"
		            format:@"Instance variables of class %@ do not match those of composed class %@.  Instance variables access from composed class is unsafe.", class, aClass];
	}
	if(!methodTypesMatch(class, aClass))
	{
		[NSException raise:@"MixinMethodTypeMismatchException"
					format:@"Method types of class %@ do not match those of mixin %@.", class, aClass];
	}
}

@implementation NSObject (Mixins)

+ (void) mixInClass:(Class)aClass
{
	Class class = (Class)self;
	checkSafeComposition(class, aClass);
	Class newSuper = calloc(1,sizeof(struct objc_class));
	/* Move ivar and method definitions to the new superclass */
	newSuper->ivars = class->ivars; class->ivars = NULL;
	newSuper->methods = class->methods; class->methods = aClass->methods;
	newSuper->instance_size = class->instance_size;
	/* Insert into the class hierarchy */
	newSuper->super_class = class->super_class;
	class->super_class = newSuper;
	newSuper->dtable = sarray_new (200, 0);
	__objc_update_dispatch_table_for_class(newSuper);
	__objc_update_dispatch_table_for_class(class);
}
+ (void) applyTraitsFromClass:(Class)aClass
{
	Class class = (Class)self;
	checkSafeComposition(class, aClass);
	struct objc_method_list * methods = aClass->methods;
	while(methods != NULL)
	{
		// Check that the method doesn't exist in this class
		for(unsigned int i=0 ; i<methods->method_count ; i++)
		{
			Method_t method = &methods->method_list[i];
			if(findMethod(sel_get_name(method->method_name), class, NO) != NULL)
			{
				[NSException raise:@"TraitMethodExistsException"
							format:@"Methods class %@ redefined in %@.", self, aClass];
			}
		}
		methods = methods->method_next;
	}
	methods = aClass->methods;
	/* Add all of the methods from the class to the mixin */
	while(methods != NULL)
	{
		addMethods(class, methods);
		methods = methods->method_next;
	}
	__objc_update_dispatch_table_for_class(class);
}
+ (void) flattenedMixinFromClass:(Class)aClass
{
	Class class = (Class)self;
	checkSafeComposition(class, aClass);
	struct objc_method_list * methods = aClass->methods;
	/* Add all of the methods from the class to the mixin */
	while(methods != NULL)
	{
		addMethods(class, methods);
		methods = methods->method_next;
	}
	/* Update the dispatch table so the runtime knows about these methods */
	__objc_update_dispatch_table_for_class(class);
}
@end
