/*
	Mirror-based reflection API for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import "ETMethodMirror.h"
#import "Macros.h"
#import "NSObject+Model.h"
#import "EtoileCompatibility.h"


@implementation ETMethodMirror
+ (id) mirrorWithMethod: (Method)method isClassMethod: (BOOL)isClassMethod
{
	return [[[ETMethodMirror alloc] initWithMethod: method
	                                 isClassMethod: isClassMethod] autorelease];
}
- (id) initWithMethod: (Method)method isClassMethod: (BOOL)isClassMethod
{
	SUPERINIT
	_method = method;
	_isClassMethod = isClassMethod;
	return self;
}

- (NSString *) name
{
	return [NSString stringWithUTF8String: sel_getName(method_getName(_method))];	
}
- (NSArray *) properties
{
	return [[super properties] arrayByAddingObjectsFromArray: 
		A(@"name", @"isClassMethod")];
}
- (BOOL) isClassMethod
{
	return _isClassMethod;
}
- (ETUTI *) type
{
	// FIXME: is there any point to having a org.etoile.method UTI? Probably not..?
	return nil;
}
- (NSString *) description
{
	return [NSString stringWithFormat:
			@"ETMethodMirror '%@', class method? %d",
			[self name], [self isClassMethod]];
}
@end


@implementation ETMethodDescriptionMirror
+ (id) mirrorWithMethodName: (const char *)name
              isClassMethod: (BOOL)isClassMethod
{
	return AUTORELEASE([[ETMethodMirror alloc] initWithMethodName: name
	                                                isClassMethod: isClassMethod]);
}
- (id) initWithMethodName: (const char *)name isClassMethod: (BOOL)isClassMethod
{
	SUPERINIT
	_name = [[NSString alloc] initWithUTF8String: name];
	_isClassMethod = isClassMethod;
	return self;
}
- (void) dealloc
{
	[_name release];
	[super dealloc];
}
- (NSString *) name
{
	return _name;
}
- (NSArray *) properties
{
	return [[super properties] arrayByAddingObjectsFromArray: 
			A(@"name", @"isClassMethod")];
}
- (BOOL) isClassMethod
{
	return _isClassMethod;
}
- (ETUTI *) type
{
	// FIXME: is there any point to having a org.etoile.method UTI? Probably not..?
	return nil;
}
- (NSString *) description
{
	return [NSString stringWithFormat:
			@"ETMethodDescriptionMirror '%@', class method? %d",
			[self name], [self isClassMethod]];
}
@end

