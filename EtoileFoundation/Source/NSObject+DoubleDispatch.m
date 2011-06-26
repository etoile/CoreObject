/*
	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  November 2007
	License:  Modified BSD (see COPYING)
 */

#import "NSObject+DoubleDispatch.h"
#import "NSObject+Etoile.h"
#import "NSString+Etoile.h"


@implementation NSObject (DoubleDispatch)

- (NSString *) doubleDispatchPrefix
{
	return @"visit";
}

- (SEL) doubleDispatchSelectorWithObject: (id)object ofType: (NSString *)aType
{
	NSString *methodName = [[[self doubleDispatchPrefix] 
		stringByAppendingString: aType] stringByAppendingString: @":"];
	return NSSelectorFromString(methodName);
}

- (id) visit: (id)object
{
	BOOL dummy = NO;
	return [self visit: object result: &dummy];
}

- (id) visit: (id)object result: (BOOL *)performed
{
	NSString *typeName = [object className];
	id item = [self tryToPerformSelector: [self doubleDispatchSelectorWithObject: object ofType: typeName]
	                          withObject: object 
	                              result: performed];

	if (performed || [typeName hasPrefix: [object typePrefix]] == NO)
		return item;

	typeName = [typeName substringFromIndex: [[object typePrefix] length]];

	return [self tryToPerformSelector: [self doubleDispatchSelectorWithObject: object ofType: typeName]
	                       withObject: object 
	                           result: performed];
}

- (BOOL) supportsDoubleDispatchWithObject: (id)object
{
	NSString *typeName = [object className];
	SEL selector = [self doubleDispatchSelectorWithObject: object ofType: typeName];

	if ([self respondsToSelector: selector])
		return YES;

	if ([typeName hasPrefix: [object typePrefix]] == NO)
		return NO;

	typeName = [typeName substringFromIndex: [[object typePrefix] length]];
	selector = [self doubleDispatchSelectorWithObject: object ofType: typeName];

	return [self respondsToSelector: selector];
}

- (id) tryToPerformSelector: (SEL)selector withObject: (id)object result: (BOOL *)performed
{
	if ([self respondsToSelector: selector])
	{
		*performed = YES;
		return [self performSelector: selector withObject: object];
	}
	else
	{
		*performed = NO;
		return nil;
	}
}

@end
