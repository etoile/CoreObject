/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObjectServer.h"
#import "NSObject+CoreObject.h"
#import "COMetadataServer.h"
#import "COGroup.h"
#import "COProxy.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COUtility.h"
#import "GNUstep.h"
#include <limits.h>

/** Must be a string and not an NSURL object for NSUserDefaults needs. */
NSString *CODefaultObjectServerURL = nil;
NSString *COCoreObjectURLProtocol = @"coreobject";
NSString *COUUIDURLProtocol = @"uuid";
// NOTE: May use later...
//NSString *COStoreConfigurationFile = @"StoreConfiguration.plist";

static COObjectServer *localObjectServer = nil;

@interface COObject (FrameworkPrivate)
- (void) _setObjectVersion: (int)version;
@end

@interface COProxy (FrameworkPrivate)
- (void) _setObjectVersion: (int)aVersion;
@end

@interface COObjectServer (UnstableAPI)
// WARNING: Don't use the following four methods, they might not behave 
// correctly or crash
- (id) objectForURL: (NSURL *)url;
- (id) objectForUUID: (ETUUID *)uuid;
- (id) managedObjectForURL: (NSURL *)url;
- (id) distantObjectForURL: (NSURL *)url;
@end

@implementation COObjectServer

/** Returns the local object server. */
+ (id) defaultServer
{
	if (localObjectServer == nil)
	{
		localObjectServer = [[self alloc] init];	
	}

	return localObjectServer;
}

/* Private method reserved for testing purpose. */
+ (void) makeNewDefaultServer
{
	RELEASE(localObjectServer);
	localObjectServer = [[self alloc] init];	
}

/* Private getter reserved for testing purpose. */
- (NSDictionary *) cachedObjects
{
	return _coreObjectTable;
}

/** <override-dummy />
	Returns the base URL of the default object store that must be defined by +localObjectServerClass
	The base URL can be defined in a subclass by overriding 
	+localObjectServerClass. */
+ (NSURL *) defaultSerializationURL;
{
	NSString *serializationDest = [DEFAULTS objectForKey: CODefaultObjectServerURL];
	NSURL *serializationURL = nil;

	if (serializationDest != nil)
	{
		serializationURL = [NSURL URLWithString: serializationDest];
	}
	else
	{
		serializationURL = [NSURL fileURLWithPath: @"~/CoreObjectStore"];
	}
	return serializationURL;
}

- (id) init
{
	return [self initWithMetadataServer: nil URL: nil];
}

// TODO: Eventually support init/save on the object server like that...
#if 0
- (id) initWithMetadataServer: (id)metadataServer URL: (NSURL *)serializationURL
{
	id existingServer = [ETDeserializer deserializeObjectWithURL: serializationURL];

	if (existingServer != nil)
	{
		RELEASE(self);
		return existingServer;
	}
	else
	{
		return [self _initWithMetadataServer: metadataServer URL: serializationURL];
	}
}
#endif

/** <init />
	Instantiates an returns a new local object server instance that uses the 
	metadata server and the library passed in parameter. */
- (id) initWithMetadataServer: (id)metadataServer URL: (NSURL *)serializationURL
{
	SUPERINIT

	if (metadataServer != nil)
	{
		ASSIGN(_metadataServer, metadataServer);
	}
	else
	{
		ASSIGN(_metadataServer, [COMetadataServer defaultServer]);
	}

	if (serializationURL != nil)
	{
		ASSIGN(_serializationURL, serializationURL);
	}
	else
	{
		ASSIGN(_serializationURL, [[self class] defaultSerializationURL]);
	}

	_objectClasses = [[NSMutableDictionary alloc] init];
	_groupClasses = [[NSMutableDictionary alloc] init];
	_coreObjectTable = [[NSMutableDictionary alloc] init];

	return self;
}

- (void) dealloc
{
	DESTROY(_objectClasses);
	DESTROY(_groupClasses);
	DESTROY(_coreObjectTable);
	DESTROY(_metadataServer);
	DESTROY(_serializationURL);
	[super dealloc];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@ cache: %@", [super description], _coreObjectTable];
}

/** Returns the metadata server that has been associated with the receiver.
    This metadata server will be used by all object contexts bound to the
    receiver. */
- (COMetadataServer *) metadataServer
{
	return _metadataServer;	
}

/* CoreObject Factory */

- (id) objectForURL: (NSURL *)url
{
	NSString *protocol = [url scheme];

	if ([protocol isEqualToString: COUUIDURLProtocol])
	{
		return [self managedObjectForURL: url];
	}
	else if ([protocol isEqualToString: COCoreObjectURLProtocol])
	{
		return [self distantObjectForURL: url];
	}
	else /* Usual case */
	{
		Class groupClass = [self groupClassForProtocolType: protocol];

		if ([groupClass isGroupAtURL: url])
		{
			return [groupClass objectWithURL: url];
		}
		else
		{
			return [[self objectClassForProtocolType: protocol] objectWithURL: url];
		}
	}
}

/** Returns the managed core object identified by UUID in the metadata server. 
    If the managed object is already available as a cached object in the 
    receiver, the cached instance is returned, otherwise the object server 
    returns a new deserialized instance by calling -managedObjectForURL:. In 
    this last case, the returned object won't belong to any object contexts. */
- (id) objectForUUID: (ETUUID *)uuid
{
	id object = [self cachedObjectForUUID: uuid];
	
	if (object == nil)
	{
		NSURL *storedObjectURL = [[self metadataServer] URLForUUID: uuid]; 

		object = [self managedObjectForURL: storedObjectURL];
	}
	
	return object;
}

/** Returns the managed core object stored at the given URL, by deserializing 
    a new instance and caching it in the receiver. The returned object doesn't 
    belong to an object context.
    If the deserialized object is already cached as another instance, identified 
    by the same UUID in the receiver, returns nil. If you really want to get a 
    new instance, you can use +[ETDeserializer deserializeObjectWithURL:]. This 
    new instance won't belong to any object context and will be disconnected 
    from the core object graph tracked by the object server.
    This method also resolves URLs with the scheme uuid:// into concrete stored 
    object URLs. */
- (id) managedObjectForURL: (NSURL *)url
{
	id storedObjectURL = nil;
	
	if ([[url scheme] isEqualToString: COUUIDURLProtocol])
	{
		ETUUID *uuid = AUTORELEASE([[ETUUID alloc] initWithString: [url path]]);
		storedObjectURL = [[self metadataServer] URLForUUID: uuid];
	}
	else
	{
		storedObjectURL = url;
	}
#if 0	
	id object = [self objectWithURL: storedObjectURL
	                        version: [self lastSnapshotVersionOfObjectWithURL: storedObjectURL]];
#else
	id object = [ETDeserializer deserializeObjectWithURL: storedObjectURL];
#endif
	BOOL deserializationFailed = (object == nil);
	
	// TODO: Verify the object conforms to COManagedObject and thereby responds 
	// to -UUID
	if (deserializationFailed)
		return nil;
	
	BOOL isAlreadyInMemory = ([self cachedObjectForUUID: [object UUID]] != nil);
	
	if (isAlreadyInMemory)
	{
		DESTROY(object);
		return nil;	
	}
	
	[self cacheObject: object];
	
	return object;
}

/** Recreates an object for a given URL and object version by deserializing 
    it and playing back invocations on it, then returns it.
    The returned instance doesn't get cached in the receiver.
    For now, this method uses simply binary delta and full save deserializers. */
- (id) objectWithURL: (NSURL *)objectURL version: (int)objectVersion
{
	// TODO: Replace the next line with  
	// int fullSaveVersion = [[NSObjectSerialBundle objectStoreWithURL: objectURL] lastVersionInBranch: @"root" ofType: @"FullSave"]
	int fullSaveVersion = [self lastSnapshotVersionOfObjectWithURL: objectURL forVersion: objectVersion];
	ETDeserializer *snapshotDeserializer = [[ETSerializer 
		defaultCoreObjectFullSaveSerializerForURL: objectURL version: fullSaveVersion] deserializer];
	
	// FIXME: -[ETSerializer deserializer] doesn't replicate the version on the 
	// returned deserializer
	[snapshotDeserializer setVersion: fullSaveVersion];
	id object = [snapshotDeserializer restoreObjectGraph];
	BOOL deserializationFailed = (object == nil);
	
	if (deserializationFailed)
		return nil;

	[object _setObjectVersion: fullSaveVersion];
	
	ETDeserializer *deltaDeserializer = [[ETSerializer 
		defaultCoreObjectDeltaSerializerForURL: objectURL version: fullSaveVersion] deserializer];
		
	[deltaDeserializer playbackInvocationsWithObject: object 
	                                     fromVersion: fullSaveVersion 
	                                       toVersion: objectVersion];
	
	NSAssert2([object objectVersion] == objectVersion, @"Recreated object "
		"version %@ doesn't match the requested version %i", object, objectVersion);
	
	return object;
}

/** Recreates the last version of an object for a given UUID by deserializing 
    it and playing back invocations on it, then returns it.
    The returned instance doesn't get registered in the receiver. 
    If the resulting object is an instance of a class expected to be used with 
    a CoreObject proxy, the object is transparently wrapped and a proxy is 
    returned. */
- (id) objectWithUUID: (ETUUID *)anUUID
{
	// TODO: If two queries badly impact the performance, only do a single one 
	// by adding a new method to COMetadataServer and calling 
	// -objectWithURL:version: directly instead of passing through 
	// -objectWithUUID:version:
	//int objectVersion = [[self metadataServer] objectVersionForUUID: anUUID];
	//NSURL *objectURL = [[self metadataServer] URLForUUID: anUUID];

	int objectVersion = [[self metadataServer] objectVersionForUUID: anUUID];

	return [self objectWithUUID: anUUID version: objectVersion];
}

/** Recreates an object for a given UUID and object version by deserializing 
    it and playing back invocations on it, then returns it.
    The returned instance doesn't get registered in the receiver.
    If the resulting object is an instance of a class expected to be used with 
    a CoreObject proxy, the object is transparently wrapped and a proxy is 
    returned. */
- (id) objectWithUUID: (ETUUID *)anUUID version: (int)objectVersion
{
	NSURL *objectURL = [[self metadataServer] URLForUUID: anUUID];
	id realObject = [self objectWithURL: objectURL version: objectVersion];

	if (realObject == nil)
		return nil;

	BOOL usesProxy = ([realObject isKindOfClass: [COObject class]] == NO);
	id object = realObject;

	if (usesProxy)
	{
		object = [COProxy proxyWithObject: realObject UUID: anUUID];
		[object _setObjectVersion: objectVersion];
	}

	return object;
}

/** Returns a proxy object for the core object path of url.
	A core object path is a sequence of group names. The proxy is obtained from 
	a remote object server by using DO as a bridge. The remote object server is 
	easy to retrieve because it is registered under the name 'coreobject://' in 
	the DO daemon running on the host of url. */
- (id) distantObjectForURL: (NSURL *)url
{
	return nil; // FIXME: Implement
}

/* Registering CoreObject backend classes */

- (void) registerObjectClass: (Class)objectClass 
             forProtocolType: (NSString *)urlScheme
{
	[_objectClasses setObject: objectClass forKey: urlScheme];
}

- (Class) objectClassForProtocolType: (NSString *)urlScheme
{
	return [_objectClasses objectForKey: urlScheme];
}

- (void) registerGroupClass: (Class)groupClass 
            forProtocolType: (NSString *)urlScheme
{
	[_groupClasses setObject: groupClass forKey: urlScheme];
}

- (Class) groupClassForProtocolType: (NSString *)urlScheme
{
	return [_groupClasses objectForKey: urlScheme];
}

/* Verify if the object is a valid core object. */
- (void) checkObject: (id)object
{
	if ([object isCoreObject] == NO)
	{
		[NSException raise: NSInvalidArgumentException format: @"Object %@ "
			@" must be a core object", object];
	}
	if ([object UUID] == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"UUID of "
			@"object %@ must not be nil", object];
	}
}

/** Adds an object to the cache of the receiver and returns NO if it failed 
	because the object was already cached.
	This method is called by object contexts when managed objects are registered. */
- (BOOL) cacheObject: (id)object 
{
	if ([[_coreObjectTable allValues] containsObject: object])
		return NO;

	ETDebugLog(@"Cache object %@", object);
	[_coreObjectTable setObject: object forKey: [object UUID]];
	return YES;

	// TODO: Use
	if ([object conformsToProtocol: @protocol(COManagedObject)])
	{
		[_coreObjectTable setObject: object forKey: [object UUID]];
	}
	else /* Basic core object */
	{
		[_coreObjectTable setObject: object forKey: [object URL]];
	}
}

/** Removes an object from the object cache of the receiver.
    This method is called by object contexts when managed objects are 
    unregistered.
    You should usually never call this method: removing an object without 
    unregistering  it from its object context will corrupt the state of 
    CoreObject. */
- (void) removeCachedObject: (id)object 
{ 
	[_coreObjectTable removeObjectForKey: [object UUID]];
	return;

	// TODO: Use
	if ([object conformsToProtocol: @protocol(COManagedObject)])
	{
		[_coreObjectTable removeObjectForKey: [object UUID]];
	}
	else /* Basic core object */
	{
		[_coreObjectTable removeObjectForKey: [object URL]];
	}
}

/** Returns the object identified by anUUID in the object cache of the receiver.
    If no entry exists for an UUID in the object cache, returns nil. 
    This method is called for resolving managed core object references by 
    -[ETDeserializer(CODeserializer) lookUpObjectForUUID:]. It acts as the basis
    for faulting and uniquing in CoreObject. */
- (id) cachedObjectForUUID: (ETUUID *)anUUID
{
	return [_coreObjectTable objectForKey: anUUID];
}

/** Merges parent references. */
- (COMergeResult) updateRelationshipsToObject: (id)anObject withInstance: (id)newObject
{
	NSMutableArray *objectsRefusingReplacement = [NSMutableArray array];
	COMergeResult mergeResult = COMergeResultFailed;
	NSError *mergeError = NULL;
	BOOL isTemporal = [newObject isTemporalInstance: anObject];

	// NOTE: Iterating through kCOParentsProperty of anObject could probably 
	// work, but may be unsafe when this method is used for restoring a context 
	// to a past version.
	FOREACHI(_coreObjectTable, managedObject)
	{
		ETDebugLog(@"Update relationship of %@ from %@ to %@", managedObject, 
			anObject, newObject);

		// TODO: Asks each managed object if the merge is possible before 
		// attempting to apply it. If the merge fails, we are in an invalid 
		// state with both object and newObject being referenced in 
		// relationships
		if ([managedObject isKindOfClass: [COGroup class]])
		{
			mergeResult = [managedObject replaceObject: anObject 
			                                  byObject: newObject
			                           isTemporalMerge: isTemporal
			                                     error: &mergeError];
			if (mergeResult == COMergeResultFailed)
				[objectsRefusingReplacement addObject: managedObject];
		}
	}

	/* Report which objects haven't handled the merge */
	if ([objectsRefusingReplacement count] > 0)
	{
		// TODO: Rather return an NSError which can be used for UI feedback 
		// rather than logging or raising an exception.
		ETLog(@"WARNING: Failed to merge temporal instance %@ of %@ into the "
			@"following %@ whose faulty classes implement "
			@"-anObjectject:byObject: in a partial or incorrect way.", 
			newObject, anObject, objectsRefusingReplacement);
	}

	return mergeResult;
}

/* Faulting */

/** Resolves the faults within the loaded managed object graph, for which a 
    cached object is available in the receiver. If no cached object exists for a
    fault marker, the fault marker is let as is.
    The loaded managed object graph is the cached object graph hold by the 
    receiver. */ 
- (void) resolvePendingFaultsWithinCachedObjectGraph
{
	FOREACHI([_coreObjectTable allKeys], uuid)
	{
		[self resolveAllFaultsForUUID: uuid];	
	}
}

/** Resolves all the faults that may exist in the cached object graph, for the 
    fault marker anUUID.
    This methods operates by traversing the whole cached object graph, and trying 
    to resolve faults every time the enumerated node is a group. */ 
- (void) resolveAllFaultsForUUID: (ETUUID *)anUUID
{
	NSMutableArray *fixedGroups = [NSMutableArray array];

	FOREACHI([_coreObjectTable allValues], object)
	{
		if ([object isKindOfClass: [COGroup class]] == NO)
			continue;
		
		if ([object tryResolveFault: anUUID])
		{
			[fixedGroups addObject: object];
		}
	}
	
	ETDebugLog(@"Resolved fault %@ in groups %@", anUUID, fixedGroups);
}

/** Returns the serialization URL.
    WARNING: Not yet used. */
- (NSURL *) serializationURL
{
	return _serializationURL;
}

/** Triggers the save of the object server state at the serialization URL 
	defined by -serializationURL. 
	The save only includes the serialization of the store/server 
	configuration. 
    WARNING: Not implemented. */
- (void) save 
{ 
	//[ETSerializer serializeObject: self toURL: [self serializationURL]];
}

/* Querying Object Version
   TODO: Move all these methods on ETSerialObjectBundle once refactored to 
   fully represent a stored object with all branches inside. */

/** Returns the first version forward in time which corresponds to a snapshot or
    a delta. If no such version can be found (no snapshot or delta available 
    unless an error occured), returns -1.
    If object hasn't been made persistent yet or isn't registered in the 
    receiver also returns -1. Hence this method returns -1 for restored
    objects not yet inserted in an object context. */
- (int) lastVersionOfObjectWithURL: (NSURL *)anURL
{
	int deltaVersion = [self lastDeltaVersionOfObjectWithURL: anURL];
	int snapshotVersion = [self lastSnapshotVersionOfObjectWithURL: anURL];
	int lastVersion = deltaVersion;

	/* The last version can be a snapshot if the object got recently restored */
	if (snapshotVersion > deltaVersion)
		lastVersion = snapshotVersion;

	return lastVersion;
}

/** Returns the first version back in time which corresponds to a delta and 
    not a snapshot. If no such version can be found (probably no delta 
    available), returns -1. */
- (int) lastDeltaVersionOfObjectWithURL: (NSURL *)anURL
{
	// TODO: Move this code into ETSerialObjectBundle, probably by adding 
	// methods such -lastVersion:inBranch: and -lastVersion. We may also cache 
	// the last version in a plist stored in the bundle to avoid the linear 
	// search in the directory.
	NSURL *serializationURL = [[anURL URLByAppendingPath: @"Delta"] URLByAppendingPath: @"root"];
	NSArray *deltaFileNames = [[NSFileManager defaultManager] 
		directoryContentsAtPath: [[serializationURL path] stringByStandardizingPath]];
	int aVersion = -1;

	/* Directory content isn't sorted so we must iterate through all the content */
	FOREACH(deltaFileNames, deltaName, NSString *)
	{
		ETDebugLog(@"Test delta %@ to find last version of %@", deltaName, object);
		int deltaVersion = [[deltaName stringByDeletingPathExtension] intValue];

		if (deltaVersion > aVersion)
			aVersion = deltaVersion;
	}

	return aVersion;
}

/** Returns the first version back in time which corresponds to a snapshot and 
	not a delta. If no such version can be found (probably no snapshot 
	available), returns -1. */
- (int) lastSnapshotVersionOfObjectWithURL: (NSURL *)anURL
{
	return [self lastSnapshotVersionOfObjectWithURL: anURL forVersion: INT_MAX];
}

/** Returns the first version back in time, right before aVersion, which 
    corresponds to a snapshot and not a delta. If no such version can be found 
    (probably no snapshot available), returns -1. */
- (int) lastSnapshotVersionOfObjectWithURL: (NSURL *)anURL forVersion: (int)targetVersion
{
	NSURL *serializationURL = [[anURL URLByAppendingPath: @"FullSave"] URLByAppendingPath: @"root"];
	NSString *branchPath = [serializationURL path];
	/* -directoryContentsAtPath: returns nil if branchPath is invalid */
	NSArray *saveNames = [[NSFileManager defaultManager] directoryContentsAtPath: branchPath];
	int aVersion = -1;

	/* Directory content isn't sorted so we must iterate through all the content */
	int saveVersion = -1;
	FOREACH(saveNames, saveName, NSString *)
	{
		ETDebugLog(@"Test %@ to find last version at %@", saveName, serializationURL);
		saveVersion = [[saveName stringByDeletingPathExtension] intValue];

		if (saveVersion > aVersion && saveVersion <= targetVersion)
			aVersion = saveVersion;
	}

	return aVersion;
}

@end
