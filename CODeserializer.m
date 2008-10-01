/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "CODeserializer.h"
#import "COSerializer.h"
#import "COObjectServer.h"
#import "COObjectContext.h"
#import "NSObject+CoreObject.h"
#import "COObject.h"

/* CoreObject Deserializer */

/* The default CoreObject Deserializer, in future storage specific code could be 
   extracted in a subclass called COFSDeserializer. It would make possible to 
   write a deserializer like COZFSDeserializer. */
@implementation ETDeserializer (CODeserializer)

+ (id) defaultCoreObjectDeserializer
{
	return [self defaultCoreObjectDeserializerWithURL: 
		[ETSerializer defaultLibraryURL]];
}

+ (id) defaultCoreObjectDeserializerWithURL: (NSURL *)aURL
{
	return [[ETSerializer defaultCoreObjectSerializerWithURL: aURL] deserializer];
}

+ (id) deserializeObjectWithURL: (NSURL *)aURL
{
	// FIXME: Move this quick-and-dirty check of the URL parameter into 
	// EtoileSerialize once the initialization code of the serialization 
	// backends is improved. We should also check that the directory is an 
	/// object bundle (put this in ETSerialObjectBundle).
	if ([aURL isFileURL] == NO 
	 || [FM fileExistsAtPath: [aURL path] isDirectory: NULL] == NO)
	{
		return nil;
	}

	// NOTE: By reading ETSerializerTest.m example, no local autorelease pool 
	// seems to be necessary for deserialization. 
	//CREATE_AUTORELEASE_POOL(pool);

	id deserializer = [self defaultCoreObjectDeserializerWithURL: aURL];
	[deserializer setBranch: @"root"];
	[deserializer setVersion: 0];
	id newInstance = [deserializer restoreObjectGraph];

	//DESTROY(pool);

	return newInstance;
}

/** Play back each of the subsequent invocations on object.
    The invocations that will be invoked on the object as target will be the 
    all invocation serialized between baseVersion and finalVersion. The first 
    replayed invocation will be 'baseVersion + 1' and the last one 
    'finalVersion'.  */
- (void) playbackInvocationsWithObject: (id)anObject 
                           fromVersion: (int)baseVersion 
                             toVersion: (int)finalVersion 
{
	id deltaDeserializer = self;
	NSInvocation *inv = nil;

	/*NSAssert3([deltaDeserializer version] == [object anObjectVersion], 
		@"Delta deserializer version %d and anObject version %d must match for "
		@"invocations playback on %@", [deltaDeserializer version], 
		[object anObjectVersion], anObject);*/

	for (int v = baseVersion + 1; v <= finalVersion; v++)
	{
		[deltaDeserializer setVersion: v];
		CREATE_AUTORELEASE_POOL(pool);
		inv = [deltaDeserializer restoreObjectGraph];
		ETDebugLog(@"Play back %@ at version %d", inv, v);
		[inv invokeWithTarget: anObject];
		[anObject deserializerDidFinish: deltaDeserializer forVersion: v];
		DESTROY(inv);
		DESTROY(pool);
	}
}

/** Patches EtoileSerialize to resolve UUIDValue to a managed core object. 
    The object is looked up in the object server which acts as a cache for 
    all core objects in memory. If the real object isn't available in memory, an 
    ETUUID instance is returned as a fault marker. */
- (id) lookUpObjectForUUID: (unsigned char *)aUUIDValue
{
	ETUUID *uuid = [[ETUUID alloc] initWithUUID: aUUIDValue];
	id otherManagedObject = [[COObjectServer defaultServer] cachedObjectForUUID: uuid];
	BOOL isNotAvailableInObjectServerCache = (otherManagedObject == nil);

	/* Use UUID as fault marker if the object isn't available in memory.
	   Each group will turn faults into real objects when -objects is called. 
	   By doing, resolved objects are automically inserted into the object 
	   context of the first parent group that unfaults them.
	   Here we don't touch the object context of the objects returned by the 
	   object server. If they are cached in the object server, that's usually 
	   means they are registered in an object context that did cache them. */
	if (isNotAvailableInObjectServerCache)
		otherManagedObject = uuid;

	// TODO: We may want to force uncached objects to be deserialized when UUIDs 
	// aren't in a group children, but rather in some ivar of other kinds of 
	// objects. In such case, the resolved/deserialized object should be 
	// inserted in the object context of 'object' variable.
	
	return otherManagedObject;
}

@end
