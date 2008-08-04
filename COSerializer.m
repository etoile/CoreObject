/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COSerializer.h"
#import "COObject.h"
#import "NSObject+CoreObject.h"

@interface ETSerializer (Private)
/* Private designated initializer of ETSerializer */
- (id) initWithBackend:(Class)aBackend forURL:(NSURL*)anURL;
@end

@interface ETSerializer (CoreObjectPrivate)
- (id) initWithBackend:(Class)aBackend objectVersion: (int)version forURL:(NSURL*)anURL;
// NOTE: Not used, may be removed later.
+ (id) defaultCoreObjectSerializerForObject: (id)object;
@end

/* CoreObject Serializer */

@implementation ETSerializer (CoreObject)

+ (Class) defaultBackendClass
{
	//return [ETSerializerBackendXML class];
	return [ETSerializerBackendBinary class];
}

+ (NSURL *) defaultLibraryURL
{
	return [NSURL fileURLWithPath: @"~/CoreObjectLibrary"];
}

+ (id) defaultCoreObjectSerializer
{
	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                                    forURL: [self defaultLibraryURL]];
}

+ (id) defaultCoreObjectSerializerWithURL: (NSURL *)aURL
{
	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                                    forURL: aURL];
}

+ (id) defaultCoreObjectSerializerForObject: (id)object
{
	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                             objectVersion: [object objectVersion]
	                                    forURL: [self serializationURLForObject: object]];
	                                    //forURL: [object URL]];
}

+ (id) defaultCoreObjectDeltaSerializerForObject: (id)object
{
	NSURL *serializationURL = [[self serializationURLForObject: object] 
		URLByAppendingPath: @"Delta"];

	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                             objectVersion: [object objectVersion]
	                                    forURL: serializationURL];
	                                    //forURL: [object URL]];
}

+ (id) defaultCoreObjectFullSaveSerializerForObject: (id)object
{
	NSURL *serializationURL = [[self serializationURLForObject: object] 
		URLByAppendingPath: @"FullSave"];

	return [ETSerializer serializerWithBackend: [self defaultBackendClass]
	                             objectVersion: [object objectVersion]
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
	[serializer serializeObject: object withName: "rootobject"];

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

#if 0
- (size_t) storeObjectFromAddress:(void*) address withName:(char*) name
{
	if(*(id*)address != nil)
	{
		[self enqueueObject:*(id*)address];
	}
	[backend storeObjectReference:COREF_FROM_ID(*(id*)address) withName:name];
	return sizeof(id);
}
#endif 

@end
