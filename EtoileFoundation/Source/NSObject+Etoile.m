/*
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  August 2007
	License: Modified BSD (see COPYING)
 */

#import "NSObject+Etoile.h"
#import "ETUTI.h"
#import "Macros.h"
#import "runtime.h"
#import "EtoileCompatibility.h"

/* Returns YES if subclass inherits directly or inherits from aClass.

Unlike +[NSObject isSubclassOfClass:] returns no if subclass and aClass are 
equal. */
static inline BOOL ETIsSubclassOfClass(Class subclass, Class aClass)
{
	Class parentClass = subclass;

	while (parentClass != Nil)
	{
		parentClass = class_getSuperclass(parentClass);
		if (parentClass == aClass)
			return YES;
	}

	return NO;
}

@implementation NSObject (Etoile)

/** Returns all descendant subclasses of the receiver class. 

The returned array doesn't include the receiver class.

You should rather use -[ETClassMirror allSubclassMirrors], this method could 
be deprecated in the future. */
+ (NSArray *) allSubclasses
{
	// NOTE: The sibling class facility of GNU runtime would eventually be 
	// faster (see GSObjCAllSubclassesOfClass as an example), however it 
	// doesn't work for classes that have not yet received their first message.
	NSMutableArray *subclasses = [NSMutableArray arrayWithCapacity: 300];
	int numberOfClasses = objc_getClassList(NULL, 0);

	if (numberOfClasses > 0)
	{
		Class *allClasses = malloc(sizeof(Class) * numberOfClasses);
		numberOfClasses = objc_getClassList(allClasses, numberOfClasses);
		for (int i = 0; i < numberOfClasses; i++)
		{
			if (ETIsSubclassOfClass(allClasses[i], self))
			 {
				[subclasses addObject: allClasses[i]];
			}
		}
		free(allClasses);
	}

	return subclasses;
}

/** Returns all subclasses which inherit directly from the receiver class. 

Subclasses that belongs to the class hierarchy of the receiver class but whose 
superclasses aren't equal to it, are excluded.

The returned array doesn't include the receiver class. */
+ (NSArray *) directSubclasses
{
	/* See also the note in +allSubclasses */
	NSMutableArray *subclasses = [NSMutableArray arrayWithCapacity: 30];
	int numberOfClasses = objc_getClassList(NULL, 0);
	 
	if (numberOfClasses > 0)
	{
		Class *allClasses = malloc(sizeof(Class) * numberOfClasses);
		numberOfClasses = objc_getClassList(allClasses, numberOfClasses);
		for (int i = 0; i < numberOfClasses; i++)
		{
			if (class_getSuperclass(allClasses[i]) == self)
			{
				[subclasses addObject: allClasses[i]];
			}
		}
		free(allClasses);
	}
	
	return subclasses;
}

/** Returns the uniform type identifier of the object. 

The UTI object encodes the type of the object in term of namespaces and 
multiple inheritance. 

By default, the UTI object is shared by all instances by being built from the 
class name. If you need to introduce type at instance level, you can do it by 
overriding this method. */
- (ETUTI *) UTI
{
	return [ETUTI typeWithClass: [self class]];
}

/** Returns the type name which is the last component of the string value returned 
by the receiver UTI object.

See also -UTI. */
- (NSString *) typeName
{
	NSString *utiString = [[self UTI] stringValue];
	NSRange range = [utiString rangeOfString: @"." options: NSBackwardsSearch];
	
	if (NSNotFound == range.location || 1 != range.length)
	{
		return @"";
	}

	return [utiString substringFromIndex: range.location + 1];
}

/** <override-dummy />
Returns the type prefix, usually the prefix part of the type name returned
by -className.

By default, returns 'NS'.

You must override this method in your subclass to indicate the prefix of your 
new class name. Take note the prefix will logically apply to every subsequent 
subclasses inheriting from the class that redefines -typePrefix. */
+ (NSString *) typePrefix
{
	return @"NS";
}

@end

