/*
	Mirror-based reflection API for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import "ETClassMirror.h"
#import "ETInstanceVariableMirror.h"
#import "ETMethodMirror.h"
#import "ETProtocolMirror.h"
#import "ETUTI.h"
#import "Macros.h"
#import "NSObject+Model.h"
#import "EtoileCompatibility.h"

@implementation ETClassMirror
+ (id) mirrorWithClass: (Class)class
{
	return [[[ETClassMirror alloc] initWithClass: class] autorelease];
}
- (id) initWithClass: (Class)class
{
	SUPERINIT
	if (class == Nil)
	{
		[self release];
		return nil;
	}
	_class = class;
	return self;
}
- (BOOL) isEqual: (id)obj
{
	return [obj isMemberOfClass: [ETClassMirror class]] &&
		[obj representedClass] == _class;
}
- (NSUInteger) hash
{
	// FIXME: doing this will cause ETClassMirrors to have hash collisions
	// with strings of the class names.. don't think this is a problem though.
	return [[self name] hash];
}
- (id <ETClassMirror>) superclassMirror
{
	return [ETClassMirror mirrorWithClass: class_getSuperclass(_class)];
}
- (NSArray *) subclassMirrors
{
	NSMutableArray *mirrors = [NSMutableArray array];
	unsigned int classesCount = objc_getClassList(NULL, 0);
	if (classesCount > 0)
	{
		Class *allClasses = malloc(sizeof(Class) * classesCount);
		classesCount = objc_getClassList(allClasses, classesCount);
		for (unsigned int i=0; i<classesCount; i++)
		{
			if (class_getSuperclass(allClasses[i]) == _class)
			{
				[mirrors addObject:
					[ETClassMirror mirrorWithClass: allClasses[i]]];
			}
		}
		free(allClasses);
	}
	return mirrors;
}
- (NSArray *) allSubclassMirrors
{
	NSMutableArray *mirrors = [NSMutableArray array];
	unsigned int classesCount = objc_getClassList(NULL, 0);
	if (classesCount > 0)
	{
		Class *allClasses = malloc(sizeof(Class) * classesCount);
		classesCount = objc_getClassList(allClasses, classesCount);
		for (unsigned int i=0; i<classesCount; i++)
		{
			for (Class cls = allClasses[i]; cls != Nil; cls = class_getSuperclass(cls))
			{
				if (class_getSuperclass(cls) == _class)
				{
					[mirrors addObject:	[ETClassMirror mirrorWithClass: allClasses[i]]];
					break;
				}
			}
		}
		free(allClasses);
	}
	return mirrors;
}

/** Returns an array of the Protocol mirrors which the class explicitly 
conforms to.

Does not include protocols conformed to by aClass's superclasses or protocols 
which the returned protocols conform to themselves. */
- (NSArray *) adoptedProtocolMirrors
{
	unsigned int protocolsCount;
	Protocol **protocols = class_copyProtocolList(_class, &protocolsCount);
	NSMutableArray *mirrors = [NSMutableArray arrayWithCapacity: protocolsCount];
	for (int i=0; i<protocolsCount; i++)
	{
		[mirrors addObject: [ETProtocolMirror mirrorWithProtocol: protocols[i]]];
	}
	if (protocols != NULL)
	{
		free(protocols);
	}
	return mirrors;
}
- (NSArray *) allAdoptedProtocolMirrors
{
	NSArray *adoptedProtocolMirrors = [self adoptedProtocolMirrors];
	// Using a set to remove duplicates from the result
	NSMutableSet *mirrors = [NSMutableSet setWithArray: adoptedProtocolMirrors];
	FOREACH(adoptedProtocolMirrors, protocol, ETProtocolMirror *)
	{
		[mirrors addObjectsFromArray: [protocol allAncestorProtocolMirrors]];
	}
	[mirrors addObjectsFromArray:
		[[self superclassMirror] allAdoptedProtocolMirrors]];
	return [mirrors allObjects];
}
/** 
 * Returns instance and class methods belonging to this class (but not those inherited
 * from superclasses).
 */
- (NSArray *) methodMirrors
{
	unsigned int instanceMethodsCount, classMethodsCount;
	Method *instanceMethods = class_copyMethodList(_class, &instanceMethodsCount);
	Class metaClass = object_getClass((id)_class);
	Method *classMethods = class_copyMethodList(metaClass, &classMethodsCount);
	NSMutableArray *mirrors = [NSMutableArray arrayWithCapacity: instanceMethodsCount + classMethodsCount];

	for (int i=0; i<instanceMethodsCount; i++)
	{
		[mirrors addObject: [ETMethodMirror mirrorWithMethod: instanceMethods[i] isClassMethod: NO]];
	}
	for (int i=0; i<classMethodsCount; i++)
	{
		[mirrors addObject: [ETMethodMirror mirrorWithMethod: classMethods[i] isClassMethod: YES]];
	}

	if (instanceMethods != NULL)
	{
		free(instanceMethods);
	}
	if (classMethods != NULL)
	{
		free(classMethods);
	}
	return mirrors;
}
- (NSArray *) allMethodMirrors
{
	if ([self superclassMirror] != nil)
	{
		// FIXME: we can do this is a more efficient way
		return [[self methodMirrors] arrayByAddingObjectsFromArray:
			[[self superclassMirror] allMethodMirrors]];
	}
	else
	{
		return [self methodMirrors];
	}
}
- (NSArray *) instanceVariableMirrorsWithOwnerMirror: (id <ETMirror>)aMirror
{
	unsigned int ivarsCount;
	Ivar *ivars = class_copyIvarList(_class, &ivarsCount);
	NSMutableArray *mirrors = [NSMutableArray arrayWithCapacity: ivarsCount];
	for (int i=0; i<ivarsCount; i++)
	{
		[mirrors addObject: [ETInstanceVariableMirror mirrorWithIvar: ivars[i]
		                                                 ownerMirror: aMirror]];
	}
	if (ivars != NULL)
	{
		free(ivars);
	}
	return mirrors;
}
- (NSArray *) instanceVariableMirrors
{
	return [self instanceVariableMirrorsWithOwnerMirror: self];
}
- (NSArray *) allInstanceVariableMirrorsWithOwnerMirror: (id <ETMirror>)aMirror
{
	NSMutableArray *mirrors = [NSMutableArray array];
	Class cls = _class;
	while (cls != Nil)
	{
		unsigned int ivarsCount;
		Ivar *ivars = class_copyIvarList(cls, &ivarsCount);
		for (int i=0; i<ivarsCount; i++)
		{
			[mirrors addObject: [ETInstanceVariableMirror mirrorWithIvar: ivars[i]
			                                                 ownerMirror: aMirror]];
		}
		if (ivars != NULL)
		{
			free(ivars);
		}
		cls = class_getSuperclass(cls);
	}
	return mirrors;
}
- (NSArray *) allInstanceVariableMirrors
{
	return [self allInstanceVariableMirrorsWithOwnerMirror: self];
}
- (BOOL) isMetaClass
{
	return class_isMetaClass(_class);
}
// FIXME: The Objective-C 2.0 API has a facility for "class variables", maybe mirror these?
- (NSString *) name
{
	return [NSString stringWithUTF8String: class_getName(_class)];
}
- (Class) representedClass
{
	return _class;
}
- (ETUTI *) type
{
	return [ETUTI typeWithClass: _class];
}
- (NSString *) description
{
	return [NSString stringWithFormat:
			@"Class mirror on %@, super = (%@)",
			[self name], [self superclassMirror]];
}

/* Collection Protocol */

- (BOOL) isOrdered
{
	return NO;
}
- (BOOL) isEmpty
{
	return [[self contentArray] count] == 0;
}
- (id) content;
{
	return [self contentArray];
}
- (NSArray *) contentArray;
{
	return [[self instanceVariableMirrors] arrayByAddingObjectsFromArray: 
			[self allMethodMirrors]];
}
- (NSEnumerator *) objectEnumerator
{
	return [[self contentArray] objectEnumerator];
}
- (NSUInteger) count
{
	return [[self contentArray] count];
}

/* Property-value coding */

- (NSArray *) properties
{
	return [[super properties] arrayByAddingObjectsFromArray: 
			A(@"name")];
}
@end

