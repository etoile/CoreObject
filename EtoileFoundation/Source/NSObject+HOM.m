/*
	Copyright (C) 2009 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "Macros.h"
#import "EtoileCompatibility.h"


@interface ETIfRespondsProxy : NSProxy
{
	id object;
}

- (id) initWithObject: (id)anObject;

@end

@implementation ETIfRespondsProxy
- (id) forwardingTargetForSelector: (SEL)aSelector
{
	if ([object respondsToSelector: aSelector])
	{
		return object;
	}
	return nil;
}
- (id) initWithObject: (id)anObject
{
	ASSIGN(object, anObject);
	return self;
}

DEALLOC(DESTROY(object))

- (BOOL) respondsToSelector: (SEL)aSelector
{
	return YES;
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
	NSMethodSignature *sig = nil;

	if ([object respondsToSelector: aSelector])
	{
		sig = [object methodSignatureForSelector: aSelector];
	}

	/* To have the possibility to discard messages not implemented by 'object' 
	   in -forwardInvocation:, we return a dummy method signature seeing that 
	   returning nil would result in the immediate calling of -doesNotRecognizeSelector: */
	if (nil == sig)
	{
		SEL dummySelector = @selector(class);
		sig = [NSObject methodSignatureForSelector: dummySelector];
	}

	return sig;
}

- (void) forwardInvocation: (NSInvocation *)anInvocation
{
	if ([object respondsToSelector: [anInvocation selector]])
	{
		[anInvocation invokeWithTarget: object];
	}
	else /* Only required on GNUstep */
	{
		id result = nil;
		[anInvocation setReturnValue: &result];
	}
}

@end

@implementation NSObject (HOM)

- (id) ifResponds
{
	return AUTORELEASE([[ETIfRespondsProxy alloc] initWithObject: self]);
}

@end
