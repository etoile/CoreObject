/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <EtoileSerialize/EtoileSerialize.h>
#import "COUtility.h"

/** Extends ETSerializer to handle the serialization of core objects. */
@interface ETSerializer (CoreObject)

// TODO: Move to COLibrary
+ (NSURL *) defaultLibraryURL;

+ (Class) defaultBackendClass;
+ (id) defaultCoreObjectSerializer;
+ (id) defaultCoreObjectSerializerWithURL: (NSURL *)aURL;
+ (id) defaultCoreObjectDeltaSerializerForObject: (id)object;
+ (id) defaultCoreObjectFullSaveSerializerForObject: (id)object;
+ (NSURL *) serializationURLForObject: (id)object;

+ (ETSerializer*) serializerWithBackend:(Class)aBackendClass 
                          objectVersion: (int)version 
                                 forURL:(NSURL*)anURL;

// Is this method really needed or used currently?
+ (BOOL) serializeObject: (id)object toURL: (NSURL *)aURL;

- (int) version;
- (id) store;
- (NSURL *) URL;

@end

@interface ETSerialObjectBundle (CoreObject)
// TODO: Move into EtoileSerialize. 
// The store should use probably URL instead of path in all cases and at least 
// expose the URL through an -URL declared in the ETSerialObjectStore protocol.
- (NSURL *) URL;
@end
