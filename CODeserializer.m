/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "CODeserializer.h"
#import "COSerializer.h"
#import "NSObject+CoreObject.h"

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

	//CREATE_AUTORELEASE_POOL(pool);

	id deserializer = [self defaultCoreObjectDeserializerWithURL: aURL];
	[deserializer setBranch: @"root"];
	[deserializer setVersion: 0];
	id newInstance = [deserializer restoreObjectGraph];

	//DESTROY(pool);

	return newInstance;
}

#if 0
/** Handle the deserialization of the core object identified by anUUID. */
- (void) loadUUID: (char *)aUUID withName: (char *)aName
{
	NSLog(@"$$$ Load CoreObject %s to name %s", aUUID, aName);

	ETUUID *uuid = [[ETUUID alloc] initWithUUID: aUUID];

	/* The object server takes care of the translation of the UUID into an URL
	   with the help of the metadata server, deserializes it and caches it. */
	object = [[COObjectServer defaultServer] objectForUUID: uuid];
}
#endif

@end
