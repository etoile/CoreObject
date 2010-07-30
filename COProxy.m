/*
   Copyright (C) 2007 David Chisnall

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#include <objc/objc.h>
#import "COProxy.h"
#import "COObjectContext.h"
#import "COObjectServer.h"
#import "COMetadataServer.h"
#import "COUtility.h"

@interface COProxy (FrameworkPrivate)
- (id) _realObject;
- (void) _setRealObject: (id)anObject;
- (void) _setObjectVersion: (int)aVersion;
- (void) setObjectContext: (COObjectContext *)ctxt;
@end

@interface COProxy (Private)
- (void) setUpCustomProxyClassIfNeeded;
- (void) startPersistency;
@end

@implementation COProxy

/** Returns an autoreleased instance initialized with -initWithObject:. */
+ (id) proxyWithObject: (id)anObject
{
	return AUTORELEASE([[[self class] alloc] initWithObject: anObject]);
}

/** Returns an autoreleased instance initialized with -initWithObject:UUID:. */
+ (id) proxyWithObject: (id)anObject UUID: (ETUUID *)aUUID
{
	return AUTORELEASE([[[self class] alloc] initWithObject: anObject UUID: aUUID]);
}

/** Returns nil, use other initializers. */
- (id) init
{
	DESTROY(self);
	return nil;
}

/** Initializes and returns a new CoreObject proxy for handling the persistency 
    of anObject.
    A random UUID is automatically picked for the receiver.
    anObject must not be nil, otherwise an NSInvalidArgumentException is raised. */
- (id) initWithObject: (id)anObject
{
	return [self initWithObject: anObject UUID: [ETUUID UUID]];
}

/* Return a cached object instead of self if the UUID exists in the cache */
#define LOOKUP_CACHED_OBJECT_AND_RETURN_ON_SUCCESS \
	id cachedObject = [[COObjectServer defaultServer] cachedObjectForUUID: aUUID]; \
 \
	if (cachedObject != nil) \
	{ \
		RETAIN(cachedObject); \
		DESTROY(self); \
		return cachedObject; \
	}

/** <init />Initializes and returns a new CoreObject proxy for handling the 
    persistency of anObject known by aUUID.
    If aUUID doesn't exist the metadata server bound to the current object 
    context, the receiver is a fresh core object, whose object version is equal 
    to 0 and immediately inserted in -[COObjectContext currentContext], then 
    snapshotted. 
    If the UUID is already in use in the metadata server and anObject is nil, 
    the object server is asked for a matching cached object, if none is found, 
    the current objet context is asked to load the object known for the given 
    UUID. The resulting object is then set as the object wrapped by the proxy.
    Once you have obtained a core object proxy, you must install the persistency 
    triggers for your model object by calling -setPersistencyMethodNames:. 

    TODO: Implement the following error checks...
    Either anObject or aUUID can be nil but not both at the same time, otherwise 
    an NSInvalidArgumentException is raised.
    In case anObject and aUUID are both different from nil, but the UUID is 
    already exists in the metadata server, an NSInvalidArgumentException is also 
    raised. */
- (id) initWithObject: (id)anObject UUID: (ETUUID *)aUUID
{
	// NOTE: Don't call -[super init], otherwise NSProxy raises an exception.

	LOOKUP_CACHED_OBJECT_AND_RETURN_ON_SUCCESS

	BOOL isNewCoreObject = (anObject != nil);

	ASSIGN(_object, anObject);
	ASSIGN(_uuid, aUUID);
	_objectVersion = -1;

	if (isNewCoreObject)
	{
		[self startPersistency]; /* Insert and snapshot the object */
	}
	else
	{
		// FIXME: Should be -currentServer or similar rather than -defaultServer
		COObjectContext *context = [[COObjectServer defaultServer] contextForObjectWithUUID: aUUID];

		[context registerObject: self]; /* Will call back -setObjectContext: */
		[self load];
	}

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

- (void) enablePersistency
{
	ETAssert(nil != _object);

	if ([_object respondsToSelector: @selector(persistencyMethodNames)])
	{
		[self setPersistencyMethodNames: [_object persistencyMethodNames]];
	}
	[self setUpCustomProxyClassIfNeeded];
}

/* Initializes objectContext and objectVersion by inserting the proxy in the 
   current object context. This creates the base version snapshot. */
- (void) startPersistency
{
	[self enablePersistency];
	[[COObjectContext currentContext] insertObject: self];
}

- (void) dealloc
{
	// NOTE: _objectContext is a weak reference
	DESTROY(_object); 
	DESTROY(_uuid); 
	free(_persistencySelectors); 
	_persistencySelectors = NULL; 
	_persistencySelectorCount = -1;

	[super dealloc];
}

/** See COManagedObject protocol. */
- (BOOL) isEqual: (id)other
{
	//if (other == nil || [other isKindOfClass: [self class]] == NO)
	//	return NO;

	BOOL hasEqualUUID = [[self UUID] isEqual: [other UUID]];
	BOOL hasEqualObjectVersion = ([self objectVersion] == [other objectVersion]);

	return hasEqualUUID && hasEqualObjectVersion;
}

/** See COManagedObject protocol. */
- (BOOL) isTemporalInstance: (id)other
{
	//if (other == nil || [other isKindOfClass: [self class]] == NO)
	//	return NO;

	BOOL hasEqualUUID = [[self UUID] isEqual: [other UUID]];
	BOOL hasDifferentObjectVersion = ([self objectVersion] != [other objectVersion]);

	return hasEqualUUID && hasDifferentObjectVersion;
}

/** Returns YES;
    See NSObject(CoreObject). */
- (BOOL) isManagedCoreObject
{
	return YES;
}

/** Returns YES.
    See NSObject(CoreObject). */
- (BOOL) isCoreObjectProxy 
{
	return YES; 
}

/** Returns an array of all selectors names whose methods calls can trigger
    persistency, by handing an invocation to the object context which can in  
    turn record it and snapshot the receiver if necessary.
    All messages which are persistency method calls are persisted only if 
    necessary, so if such a message is sent by another managed object part of 
    the same object context, it won't be recorded (see COObjectContext for a 
    more thorough explanation).
    -forwardInvocation: decides how to handle an invocation based on these  
    returned method names. */
- (NSArray *) persistencyMethodNames
{
	NSMutableArray *methodNames = [NSMutableArray array];

	for (int i = 0; i < _persistencySelectorCount; i++)
	{
		[methodNames addObject: NSStringFromSelector(_persistencySelectors[i])];
	}

	return methodNames;
}

/** Sets an array of all selectors names whose methods calls should trigger
    persistency, by handing an invocation to the object context.
    See -persistencyMethodNames. */
- (void) setPersistencyMethodNames: (NSArray *)methodNames
{
	_persistencySelectorCount = [methodNames count];

	if (_persistencySelectors != NULL)
		free(_persistencySelectors);
	_persistencySelectors = calloc(_persistencySelectorCount, sizeof(SEL));

	for (int i = 0; i < _persistencySelectorCount; i++)
	{
		_persistencySelectors[i] = NSSelectorFromString([methodNames objectAtIndex: i]);
	}
}

/** Returns whether aSelector matches a persistent method name declared in 
    -persistencyMethodNames.
    This method is called by -forwardInvocation:, therefore subclasses must not
    alter its current behavior, even if they extend it. */
- (BOOL) isPersistencySelector: (SEL)aSelector
{
	for (int i = 0; i < _persistencySelectorCount; i++)
	{
		if (sel_eq(_persistencySelectors[i], aSelector))
			return YES;
	}

	return NO;
}

/* Framework private method that returns the object wrapped by the proxy, used 
   mostly by COObjectContext as the target for snapshots, invocation playback 
   and invocation forwarding. */
- (id) _realObject
{
	return _object;
}

/* Framework private method that sets the object wrapped by the proxy, used 
   mostly by COObjectContext as the target for replacing the wrapped object or 
   restoring a temporal instance. */
- (void) _setRealObject: (id)anObject
{
	ASSIGN(_object, anObject);
}

/** See COManagedObject protocol. */
- (ETUUID *) UUID
{
	return _uuid;
}

/** See COManagedObject protocol. */
- (NSUInteger) hash
{
	return [_uuid hash];
}

/** See COManagedObject protocol. */
- (int) objectVersion
{
	return _objectVersion;
}

/* Framework private method used on serialization and deserialization, either 
   delta or snapshot. */
- (void) _setObjectVersion: (int)aVersion
{
	_objectVersion = aVersion;
}

/** Restores the real object to the given object version if possible, then 
   commits the restored version by taking a snapshot. Returns the current object 
   version + 1 if the receiver has been successfully restored, otherwise returns 
   -1. If no restore operation has been carried, the requested object version 
   is already the current one, returns aVersion.
   See -[COObjectContext objectByRestoringObject:toVersion:immediately: for 
   a detailed account of the restoration mechanism. */
- (int) restoreObjectToVersion: (int)aVersion
{
	id restoredObject = [[self objectContext] objectByRestoringObject: self 
	                                                        toVersion: aVersion
	                                                 mergeImmediately: YES];

	if (restoredObject == nil)
		return -1;

	NSAssert(restoredObject == self, @"For a COProxy instance, the resulting "
		"restored object must be identical to the proxy");
	return aVersion;
}

/** See COManagedObject protocol. */
- (COObjectContext *) objectContext
{
	return _objectContext;
}

/* Framework private method used only by COObjectContext on insertion/removal of 
   objects. */
- (void) setObjectContext: (COObjectContext *)ctxt
{
	/* The object context is our owner and retains us. */
	_objectContext = ctxt;
}

/** See COManagedObject protocol.
    WARNING: Not yet implemented. */
- (NSDictionary *) metadatas
{
	return nil;
}

- (BOOL) respondsToSelector: (SEL)aSelector
{
	if ([[self class] respondsToSelector: aSelector]
	 || [_object respondsToSelector: aSelector])
	{
		return YES;
	}

	return NO;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
	NSMethodSignature *sig = [[self class] methodSignatureForSelector: aSelector];

	if (sig == nil)
		sig = [_object methodSignatureForSelector: aSelector];

	return sig;
}

/* Speeds up the proxy forwarding when the message doesn't trigger persistency.
More explanations in -forwardInvocation:.

Alternative possibilities, we don't use:
    - reimplement NSObject and NSProxy methods to bypass -forwardInvocation:
    - synthetize methods at runtime for each methods declared in 
      -persistencyMethodNames
    - macros to help the developer to manually syntethize persistency methods at 
      compile time. */ 
- (id) forwardingTargetForSelector: (SEL)aSelector
{
	return [self isPersistencySelector: aSelector] ? nil : _object;
}

/** Forwards the invocation to the real object after serializing it. Every few
invocations, it will also save a full copy of the object, see 
-[COObjectContext setSnapshotTimeInterval:] to specify a custom interval.

See also -[COObjectContext recordInvocation:] to understand the persistency
mechanism in details.

When a message is only implemented by the real object but doesn't trigger 
persistency, when the runtime supports it (e.g. GNUstep libobjc2) 
-forwardingTargetForSelector: is used to speed up the execution.

Note: A tricky point is that both the proxy and the real object must react to 
introspection correctly (as a single object). Unknown messages that neither the 
proxy or the real object implement must also result in an unknown selector 
exception as expected. */
- (void) forwardInvocation: (NSInvocation *)anInvocation
{
	SEL selector = [anInvocation selector];

	/* For instropection, we pass messages such as -isKindOfClass: to the real 
	   object. By default -[NSProxy isKindOfClass:] calls -forwardInvocation:.
	   We do the same for NSObject methods such as -descriptionWithLocale:, 
	   -isGroup etc. not implemented by NSProxy and which must not be recorded 
	   but just forwarded. */
	if ([[self class] respondsToSelector: selector]
	 || [NSObject instancesRespondToSelector: selector])
	{
		[anInvocation invokeWithTarget: _object];
	}
	else if ([self isPersistencySelector: selector])
	{
		ETDebugLog(@"Will record invocation %@ for proxy %@ in %@", anInvocation,
			self, _objectContext);

		int prevObjectVersion = _objectVersion;

		_objectVersion = [_objectContext recordInvocation: anInvocation];
		if (_objectVersion != prevObjectVersion)
			[_objectContext endRecord];
	}
	else 
	{
		/* We also forwards if -respondsToSelector: has returned NO, 
		   -doesNotRecognizeSelector: will called on the real object then. */
		[anInvocation invokeWithTarget: _object];
	}
}

/** Initializes the receiver as a fault whose real object is bound to the fault 
description.

Doesn't load the real object unlike other initializers. 

The class argument is ignored since COProxy doesn't support -futureClass. */
- (id) initWithFaultDescription: (NSDictionary *)aFaultDesc futureClassName: (NSString *)aFutureClassName
{
	ETUUID *aUUID = [aFaultDesc objectForKey: kCOUUIDCoreMetadata];

	LOOKUP_CACHED_OBJECT_AND_RETURN_ON_SUCCESS;

	COObjectContext *context = AUTORELEASE([(COObjectContext *)[COObjectContext alloc] initWithUUID: 
		[aFaultDesc objectForKey: kCOContextCoreMetadata]]);

	ASSIGN(_uuid, aUUID);
	_objectVersion = -1;
	[context registerObject: self]; /* Will call back -setObjectContext: */

	return self;
}

/** Returns whether the real object has to be loaded. 

See COFault protocol. */
- (BOOL) isFault
{
	return (_object == nil);
}

/** Always returns nil.

See COFault protocol. */
- (NSString *) futureClassName
{
	return nil;
}

/** Loads the real object wrapped by the proxy and enables the persistency.

If -isFault returns NO, does nothing.
 
If the loading fails, logs a warning.

Warning: returns nil in all cases currently. */
- (NSError *) load
{
	if ([self isFault] == NO)
		return nil;

	/* Try to load the object if the UUID exists in the metadata DB */
	id loadedObject = [[COObjectServer defaultServer] rawObjectWithUUID: _uuid];

	if (loadedObject == nil)
	{
		ETLog(@"WARNING: Invalid fault ! Object %@ cannot be loaded", _uuid);
		return nil;
	}

	ASSIGN(_object, loadedObject);
	// TODO: We should rather get the version with -rawObjectWithUUID:
	_objectVersion = [_objectContext lastVersionOfObject: self];
	[self enablePersistency];

	return nil;
}

@end
