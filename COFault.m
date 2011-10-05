/*
   Copyright (C) 2009 Quentin Mathe <qmathe gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COFault.h"
#import "COEditingContext.h"
#import "COObject.h"
#include <objc/runtime.h>

@implementation COObjectFault

- (BOOL) isFault
{
	return YES;
}

- (NSString *) futureClassName
{
	return NSStringFromClass([_context classForEntityDescription: _entityDescription]);
}

- (ETUUID *) UUID
{
	return _uuid;
}

- (unsigned int) hash
{
	return [[self UUID] hash];
}

- (COEditingContext *) editingContext
{
	return _context;
}

- (BOOL) isEqual: (id)other
{
	if (other == nil || [other isKindOfClass: [self class]] == NO)
		return NO;

	// NOTE: Should we test the object version...
	return [_uuid isEqual: [self UUID]];
}

- (BOOL)isKindOfClass: (Class)cl
{
	return [NSClassFromString([self futureClassName]) isSubclassOfClass: cl];
}

- (NSError *) unfaultIfNeeded
{
	if (_isIgnoringDamageNotifications)
		return nil;

	object_setClass(self, NSClassFromString([self futureClassName]));

	// NOTE: I would move that to COObject initialization rather, the spared 
	// space looks negligible (Quentin).
	assert(_variableStorage == nil);
	_variableStorage = [[NSMapTable alloc] init];

	[_context loadObject: (COObject *)self];
	// TODO: Move to -loadObject:atRevision: probably
	[(COObject *)self awakeFromFetch];

	// TODO: Return a NSError or report issues in another way
	return nil;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
	return [NSClassFromString([self futureClassName]) instanceMethodSignatureForSelector: aSelector];
}

- (void) forwardInvocation: (NSInvocation *)inv
{
	if ([self isFault] == NO)
		return [super forwardInvocation: inv];
	
	[self unfaultIfNeeded];
	[inv invokeWithTarget: self];
}

@end

