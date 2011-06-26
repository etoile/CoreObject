/*
	Mirror-based reflection API for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import "ETObjectMirror.h"
#import "ETClassMirror.h"
#import "Macros.h"
#import "NSObject+Trait.h"
#import "NSObject+Model.h"
#import "NSObject+Prototypes.h"
#import "EtoileCompatibility.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation ETObjectMirror

+ (void) initialize
{
	if (self != [ETObjectMirror class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

+ (id) mirrorWithObject: (id)object
{
	return [[[ETObjectMirror alloc] initWithObject: object] autorelease];
}

- (id) initWithObject: (id)object
{
	SUPERINIT
	if (object == nil)
	{
		[self release];
		return nil;
	}
	_object = object;
	return self;
}
- (BOOL) isEqual: (id)obj
{
	return [obj isMemberOfClass: [ETObjectMirror class]] &&
		[obj representedObject] == _object;
}
- (NSUInteger) hash
{
	// NOTE: The cast prevents a compiler warning about pointer truncation on
	// 64bit systems.
	return (uintptr_t) _object;
}
- (id <ETClassMirror>) classMirror
{
	return [ETClassMirror mirrorWithClass: object_getClass(_object)];
}
- (id <ETClassMirror>) superclassMirror
{
	return [[self classMirror] superclassMirror];
}
- (id <ETObjectMirror>) prototypeMirror
{
	// FIXME: this assumes object is an NSObject subclass
	// and we are using ETPrototype
	if ([self isPrototype])
	{
		return [ETObjectMirror mirrorWithObject: [_object prototype]];
	}
	else
	{
		return nil;
	}
}
- (NSArray *) instanceVariableMirrors
{
	// FIXME: Should these ivar mirrors reflect the contents of this object's ivars/be editable?
	return [[self classMirror] instanceVariableMirrorsWithOwnerMirror: self];
}
- (NSArray *) allInstanceVariableMirrors
{
	// FIXME: Should these ivar mirrors reflect the contents of this object's ivars/be editable?
	return [[self classMirror] allInstanceVariableMirrorsWithOwnerMirror: self];
}
- (NSArray *) methodMirrors
{
	// FIXME: If this is a prototype object, return any methods added to this object
	return [NSArray array];
}
- (NSArray *) allMethodMirrors
{
	// FIXME: If this is a prototype object, return any methods added to this object
	// as well as any methods added to this object's prototypes.
	return [NSArray array];
}
- (NSArray *) slotMirrors
{
	return [[self methodMirrors] arrayByAddingObjectsFromArray:
		[self instanceVariableMirrors]];
}
- (NSArray *) allSlotMirrors
{
	return [[self allMethodMirrors] arrayByAddingObjectsFromArray:
		[self allInstanceVariableMirrors]];
}
- (NSString *) name
{
	// FIXME: What should the name of an object be?
	return [[self classMirror] name];
}
- (id) representedObject
{
	return _object;
}
- (BOOL) isPrototype
{
	// FIXME: this assumes object is an NSObject subclass
	// and we are using ETPrototype
	// FIXME: Check without calling a method on _object?
	return [_object isPrototype];
}
- (ETUTI *) type
{
	return [[self classMirror] type];
}
- (NSString *) description
{
	return [NSString stringWithFormat:
			@"ETObjectMirror on %@\nClass mirror: %@",
			_object, [self classMirror]];
}

/* Collection Protocol */

- (id) content
{
	return [self contentArray];
}

- (NSArray *) contentArray
{
	return [self allSlotMirrors];
}

/* Property-value coding */

- (NSArray *) propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
			A(@"isPrototype", @"representedObject")];
}

@end


