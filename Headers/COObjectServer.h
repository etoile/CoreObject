/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>


/** COObjectServer is a convenient core object factory that can takes care of 
	instantiating the right object for a given URL based on the URL 
	scheme/protocol and the object and group classes registered for it. 
	You usually use a single a object server per application that acts as a 
	shared cache of all core objects in memory for all related core object 
	contexts. You may instantiate more than one object server but in this case 
	each one is a sandbox and rolling back an object owned by one or several 
	object servers won't trigger the update of all references to it that exist
	outside of the active object server (the one bound to the object context 
	that got asked to roll back the object). */
@interface COObjectServer: NSObject
{
	NSURL *_serializationURL;
	NSMutableDictionary *_objectClasses;
	NSMutableDictionary *_groupClasses;
	id _metadataServer;
	id _defaultLibrary;
	id _coreObjectTable; /** Objects by UUIDs or by URLs if no existing UUIDs */
}

+ (id) defaultServer;
+ (NSURL *) defaultSerializationURL;

- (id) initWithMetadataServer: (id)metadataServer URL: (NSURL *)url;

//- (void) setUpRootGroup;
//- (void) setUpPublishedObjectsOverDO;

/* CoreObject Factory */

- (id) objectForURL: (NSURL *)url;
- (id) objectForUUID: (ETUUID *)uuid;
- (id) managedObjectForURL: (NSURL *)url;
- (id) distantObjectForURL: (NSURL *)url;

//- (COGroup *) rootGroup;

/* Registering CoreObject backend classes */

- (void) registerObjectClass: (Class)objectClass 
             forProtocolType: (NSString *)urlScheme;
- (Class) objectClassForProtocolType: (NSString *)urlScheme;
- (void) registerGroupClass: (Class)groupClass 
            forProtocolType: (NSString *)urlScheme;
- (Class) groupClassForProtocolType: (NSString *)urlScheme;
// TODO: In future, we may allow to delegate the object requests to another 
// object server (which can be located on another host) for a given url 
// protocol. This feature may not be really needed though.
//+ (void) registerObjectServer: (COObjectServer *)objectServer 
//              forProtocolType: (NSString *)urlScheme
//+ (COObjectServer *) objectServerForProtocolType: (NSString *)urlScheme;

/* Utility */

// TODO: We may want to store/serialize the configuration of the object server 
// into a property list file, rather than serializing it with EtoileSerialize 
// flat formats which aren't really edition-friendly.
//- (id) initWithConfigurationFromURL: (NSURL *)url;
//- (id) propertyList;
//- (void) readConfigurationFromURL: (NSURL *)url;
//- (void) writeConfigurationToURL: (NSURL *)url;

/* Shared Object Cache */

- (BOOL) cacheObject: (id)object;
- (void) removeCachedObject: (id)object;
- (id) cachedObjectForUUID: (ETUUID *)anUUID;

/** Returns the serialization URL. */
- (NSURL *) serializationURL;
- (void) save;
- (void) handleError: (NSError *)error;

@end

/* URL Protocols/Schemes */

extern NSString *COUUIDURLProtocol;
extern NSString *COCoreObjectURLProtocol;

/* Defaults */

extern NSString *CODefaultObjectServerURL;
