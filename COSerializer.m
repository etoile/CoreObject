/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COSerializer.h"
#import "NSObject+CoreObject.h"

/* CoreObject Serializer */

@implementation ETSerializer (CoreObject)

+ (NSURL *) defaultLibraryURL
{
	return [NSURL fileURLWithPath: @"~/CoreObjectLibrary"];
}

+ (id) defaultCoreObjectSerializer
{
	return [ETSerializer serializerWithBackend: [ETSerializerBackendBinary class]
	                                    forURL: [self defaultLibraryURL]];
}

+ (id) defaultCoreObjectSerializerWithURL: (NSURL *)anURL
{
	return [ETSerializer serializerWithBackend: [ETSerializerBackendBinary class]
	                                    forURL: anURL];
}

@end
