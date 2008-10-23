/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COSerializer.h"
#import "COObject.h"
#import "COMetadataServer.h"
#import "NSObject+CoreObject.h"

@interface ETSerializer (Private)
/* Private designated initializer of ETSerializer */
- (id) initWithBackend:(Class)aBackend forURL:(NSURL*)anURL;
@end

@interface ETSerializer (CoreObjectPrivate)
- (id) initWithBackend:(Class)aBackend objectVersion: (int)version forURL:(NSURL*)anURL;
// NOTE: Not used, may be removed later.
+ (id) defaultCoreObjectSerializerForObject: (id)object;
+ (NSURL *) libraryURLForTest; // Not implemented here (see TestSerializer.m)
@end

/* CoreObject Serializer */

@implementation ETSerializer (CoreObject)

+ (Class) defaultBackendClass
{
	return [ETSerializerBackendBinary class];
}

+ (NSURL *) defaultLibraryURL
{
#ifdef UKTEST
	if ([self respondsToSelector: @selector(libraryURLForTest)])
		return [self libraryURLForTest];
#endif
	return [NSURL fileURLWithPath: [@"~/CoreObjectLibrary" stringByStandardizingPath]];
}

// TODO: Once ETObjectStore has been refactored to represent an object bundle 
// as whole. We could probably keep -defaultCoreObjectSerializerWithURL: and 
// get rid of the next two methods by attaching both snapshot and delta 
// serialization to ETSerializer with methods such -serializeObject:inBranch:

+ (id) defaultCoreObjectSerializerWithURL: (NSURL *)aURL
{
	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                                    forURL: aURL];
}

+ (id) defaultCoreObjectDeltaSerializerForURL: (NSURL *)anURL
                                      version: (int)objectVersion
{
	NSURL *serializationURL = [anURL URLByAppendingPath: @"Delta"];

	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                             objectVersion: objectVersion
	                                    forURL: serializationURL];
	                                    //forURL: [object URL]];
}

+ (id) defaultCoreObjectFullSaveSerializerForURL: (NSURL *)anURL
                                         version: (int)objectVersion
{
	NSURL *serializationURL = [anURL URLByAppendingPath: @"FullSave"];

	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                             objectVersion: objectVersion
	                                    forURL: serializationURL];
	                                    //forURL: [object URL]];
}

/* Retrieves the URL where an object is presently serialized, or if it hasn't 
   been serializerd yet, builds the URL by taking the library to which the 
   object belongs to. */
+ (NSURL *) serializationURLForObject: (id)object
{
	// TODO: Modify once we have proper library support.
	return [[ETSerializer defaultLibraryURL] URLByAppendingPath: [[object UUID] stringValue]];
}

+ (ETSerializer*) serializerWithBackend:(Class)aBackendClass 
                          objectVersion: (int)version 
                                 forURL:(NSURL*)anURL
{
	ETSerializer * serializer = [[[self alloc] initWithBackend:aBackendClass
		objectVersion: version forURL:anURL] autorelease];
	
	return serializer;
}

+ (ETSerializer*) serializerWithBackend:(Class)aBackendClass forURL:(NSURL*)anURL
{
	ETSerializer * serializer = [[[self alloc] initWithBackend:aBackendClass
		forURL:anURL] autorelease];
	
	return serializer;
}

+ (BOOL) serializeObject: (id)object toURL: (NSURL *)aURL
{
	BOOL result = NO;

	CREATE_AUTORELEASE_POOL(pool);

	id serializer = [self defaultCoreObjectSerializerWithURL: aURL];
	[serializer serializeObject: object withName: @"rootobject"];

	DESTROY(pool);

	return result;
}

- (id) initWithBackend:(Class)aBackend objectVersion: (int)version forURL:(NSURL*)anURL
{
	self = [self initWithBackend:aBackend forURL:anURL];

	objectVersion = version;

	return self;
}

- (int) version
{
	return objectVersion;
}

/** Returns the serialization URL used to initialize the receiver. */
- (NSURL *) URL
{
	return [[self store] URL];
}

/** Returns the object store identified by -URL, which receives the serialized 
    data. */
- (id) store
{
	return store;
}

- (size_t) storeObjectFromAddress: (void *)address withName: (char *)name
{
	id object = *(id*)address;

	if ([object isManagedCoreObject]) /* Store managed Core Object */
	{
		ETDebugLog(@"Store managed object %@ with name %s and uuid %-0.8x", 
			object, name, [[object UUID] UUIDValue]);
		[backend storeUUID: [[object UUID] UUIDValue] withName: name];
		return ETUUIDSize;
	}
	else /* Store normal object */
	{
		ETDebugLog(@"Store object %@ with name %s", object, name);
		if (object != nil)
		{
			[self enqueueObject: object];
		}
		[backend storeObjectReference: COREF_FROM_ID(object) withName: name];
		/* The returned size doesn't seem to be ever used for objects, hence even 
		   if the object isn't serialized as part of the current object graph, 
		   everything should be fine. */
		return sizeof(id);
	}
}

@end

@implementation ETSerialObjectBundle (CoreObject)

/** Returns the URL where the serialized data are stored for the receiver. */
- (NSURL *) URL
{
	/* We standardize the path, because we don't support relative URL in the 
	   metadata server currently. */
	return [[NSURL fileURLWithPath: bundlePath] absoluteURL];
}

@end

