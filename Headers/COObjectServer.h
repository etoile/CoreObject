/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObjectContext.h>

@class COMetadataServer;

/** COObjectServer is a convenient core object factory that can takes care of 
	instantiating the right object for a given URL based on the URL 
	scheme/protocol and the object and group classes registered for it. 
	You usually use a single a object server per application that acts as a 
	shared cache of all core objects in memory for all related core object 
	contexts. Hence the object server is the basic mechanism for uniquing and 
	faulting in CoreObject.
	You may instantiate more than one object server but in this case 
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

- (COMetadataServer *) metadataServer;

//- (void) setUpRootGroup;
//- (void) setUpPublishedObjectsOverDO;

/* CoreObject Factory */

- (id) objectForURL: (NSURL *)url;
- (id) objectForUUID: (ETUUID *)uuid;
- (id) managedObjectForURL: (NSURL *)url;
- (id) distantObjectForURL: (NSURL *)url;

- (id) objectWithURL: (NSURL *)objectURL version: (int)objectVersion;
- (id) objectWithUUID: (ETUUID *)anUUID version: (int)objectVersion;
- (id) objectWithUUID: (ETUUID *)anUUID;

//- (COGroup *) rootGroup;

/* Libraries */

//- (void) registerLibrary: (COOGroup *)aGroup forType: (NSString *)libraryType;
//- (COGroup *) libraryForType: (NSString *)libraryType;
//- (id) photoLibrary;
//- (id) musicLibrary;

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

- (NSURL *) serializationURL;
- (void) save;

/* Shared Object Cache */

- (BOOL) cacheObject: (id)object;
- (void) removeCachedObject: (id)object;
- (id) cachedObjectForUUID: (ETUUID *)anUUID;

- (COMergeResult) updateRelationshipsToObject: (id)anObject withInstance: (id)newObject;

/* Faulting */

- (void) resolvePendingFaultsWithinCachedObjectGraph;
- (void) resolveAllFaultsForUUID: (ETUUID *)anUUID;

// TODO: In future, we may need some faulting mechanism if we browse very 
// large object graphs as the generic ObjectManager will make possible.
//- (BOOL) hasFaultForUUID: (ETUUID *)uuid;
//- (void) turnCachedObjectsIntoFaultsIfNotUsed;

/* Querying Object Version (to be moved to COSerializer and ETObjectSerialStore) */

- (int) lastVersionOfObjectWithURL: (NSURL *)anURL;
- (int) lastDeltaVersionOfObjectWithURL: (NSURL *)anURL;
- (int) lastSnapshotVersionOfObjectWithURL: (NSURL *)anURL;
- (int) lastSnapshotVersionOfObjectWithURL: (NSURL *)anURL forVersion: (int)targetVersion;

@end

/* URL Protocols/Schemes */

extern NSString *COUUIDURLProtocol;
extern NSString *COCoreObjectURLProtocol;

/* Defaults */

extern NSString *CODefaultObjectServerURL;
