/*
   Copyright (C) 2007 David Chisnall

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/NSObject+CoreObject.h>

@class COObjectContext;

/**
 * The COProxy class is a simple proxy which is responsible for wrapping a
 * model object being managed by CoreObject. The object will be serialized as
 * will every message sent to it, allowing deterministic replay of the object's
 * entire lifecycle.
 *
 * An object wrapped by this proxy should be the entry point into an object
 * graph representing a document, or a major component in a composite document
 * (e.g. an image in a larger work).  
 */
@interface COProxy : NSProxy <COManagedObject>
{
	/* Object identity */
	ETUUID *_uuid;
	/* Real object */
	id _object;
	/* Object context to which the object belongs to */
	COObjectContext *_objectContext;
	/* Current version of the real object */
	int _objectVersion;
	/* Arrays of selectors for which invocations are recorded */
	SEL *_persistencySelectors;
	/* Size of the previous array of selectors */
	int _persistencySelectorCount;
}

+ (id) proxyWithObject: (id)anObject;
+ (id) proxyWithObject: (id)anObject UUID: (ETUUID *)aUUID;

- (id) initWithObject: (id)anObject UUID: (ETUUID *)aUUID;
- (id) initWithObject: (id)anObject;

- (NSArray *) persistencyMethodNames;
- (void) setPersistencyMethodNames: (NSArray *)methodNames;
- (BOOL) isPersistencySelector: (SEL)aSelector;

- (BOOL) isEqual: (id)other;
- (BOOL) isTemporalInstance: (id)other;

- (BOOL) isCoreObjectProxy;
- (BOOL) isManagedCoreObject;

- (ETUUID *) UUID;
- (int) objectVersion;
- (int) restoreObjectToVersion: (int)aVersion;
- (COObjectContext *) objectContext;

- (NSDictionary *) metadatas;

@end
