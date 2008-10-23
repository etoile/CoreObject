/*
   Copyright (C) 2007 David Chisnall

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COProxy.h"
#import "COObjectContext.h"

@interface COProxy (FrameworkPrivate)
- (id) _realObject;
- (void) _setRealObject: (id)anObject;
- (void) _setObjectVersion: (int)aVersion;
- (void) setObjectContext: (COObjectContext *)ctxt;
@end

@interface COProxy (Private)
- (void) setUpCustomProxyClassIfNeeded;
@end

@implementation COProxy

+ (id) proxyWithObject: (id)anObject UUID: (ETUUID *)aUUID
{
	return AUTORELEASE([[[self class] alloc] initWithObject: anObject UUID: aUUID]);
}

- (id) initWithObject: (id)anObject
{
	return [self initWithObject: anObject UUID: [ETUUID UUID]];
}

- (id) initWithObject: (id)anObject UUID: (ETUUID *)aUUID
{
	SUPERINIT

	ASSIGN(_object, anObject);
	ASSIGN(_uuid, aUUID);

	[self setUpCustomProxyClassIfNeeded];

	return self;
}

- (void) setUpCustomProxyClassIfNeeded
{
	Class objectClass = [_object class];
	Class proxyClass = Nil;

	while (objectClass != Nil)
	{
		proxyClass = NSClassFromString([NSString stringWithFormat:@"COProxy_%s", objectClass->name]);

		if (Nil != proxyClass)
		{
			self->isa = proxyClass;
			break;
		}
		objectClass = objectClass->super_class;
	}
}

DEALLOC(DESTROY(_object); DESTROY(_uuid); DESTROY(_objectContext);)

- (BOOL) isCoreObjectProxy 
{
	return YES; 
}

- (BOOL) isManagedCoreObject
{
	return YES;
}

- (id) _realObject
{
	return _object;
}

- (void) _setRealObject: (id)anObject
{
	ASSIGN(_object, anObject);
}

- (ETUUID *) UUID
{
	return _uuid;
}

- (int) objectVersion
{
	return _objectVersion;
}

- (void) _setObjectVersion: (int)aVersion
{
	_objectVersion = aVersion;
}

- (int) restoreObjectToVersion: (int)aVersion
{
	id restoredObject = [[self objectContext] objectByRestoringObject: _object 
	                                                        toVersion: aVersion
	                                                 mergeImmediately: YES];

	if (restoredObject == nil)
		return -1;

	NSAssert(restoredObject == self, @"For a COProxy instance, the resulting "
		"restored object must be identical to the proxy");
	return aVersion;
}

- (COObjectContext *) objectContext
{
	return _objectContext;
}

- (void) setObjectContext: (COObjectContext *)ctxt
{
	/* The object context is our owner and retains us. */
	_objectContext = ctxt;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
	return [_object methodSignatureForSelector: aSelector];
}

/** Forwards the invocation to the real object after serializing it. Every few
    invocations, it will also save a full copy of the object.
    See also -[COObjectContext recordInvocation:]. */
- (void) forwardInvocation: (NSInvocation *)anInvocation
{
	[_objectContext recordInvocation: anInvocation];
}

@end
