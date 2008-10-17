/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObjectContext.h"
#import "COObject.h"
#import "COGroup.h"
#import "COSerializer.h"
#import "CODeserializer.h"
#import "COMetadataServer.h"
#import "COObjectServer.h"

@interface COObjectContext (Private)
- (void) commitMergeOfInstance: (id)temporalInstance forObject: (id)anObject;
@end

@interface COObjectContext (GraphRollback)
- (int) lookUpVersionIfRestorePointAtVersion: (int)aVersion;
- (NSMutableDictionary *) findAllObjectVersionsMatchingContextVersion: (int)aVersion;
- (void) printQueryResult: (PGresult *)result;
- (void) discardCurrentObjectsNotYetCreatedAtVersion: (int)aVersion 
                                   forObjectVersions: (NSDictionary *)restoredObjectVersions;
- (NSSet *) restoreObjectsIfNeededForObjectVersions: (NSDictionary *)restoredObjectVersions;
- (void) logRestoreContextVersion: (int)aVersion;
@end


@implementation COObjectContext (GraphRollback)

// TODO: Break -restoreVersion: in several small methods.
// TODO: Handle trimmed history...
// This done by querying contextVersion superior to aVersion rather than 
// inferior as we do in the first query.
// SELECT [...] WHERE contextVersion > aVersion ORDER BY contextVersion
// foreach registeredObject not in rolledbackObjectVersions
// {
//		version = first object version right after aVersion
//	    rolledbackObjectVersions setObject: --version forKey: [object UUID]
// }

// TODO: Rewrite to share code with -objectForUUID:
- (void) mergeFreshObject: (id)anObject
{
	id object = [[self objectServer] cachedObjectForUUID: [anObject UUID]];
	BOOL boundToCachedObject = (object != nil);

	if (boundToCachedObject)
	{
		ETLog(@"WARNING: Object %@ already cached conflicting with fresh object %@", object, anObject);
	}

	if ([anObject isKindOfClass: [COGroup class]])
		[anObject setHasFaults: YES];
	[self registerObject: anObject];
}

- (id) objectForUUID: (ETUUID *)anUUID version: (int)objectVersion
{
	id object = [[self objectServer] objectWithUUID: anUUID version: objectVersion];

	[self commitMergeOfInstance: object forObject: nil];
	[self mergeFreshObject: object];

	return object;
}

- (int) lastObjectVersionForUUID: (ETUUID *)aUUID
{
	return [[self metadataServer] objectVersionForUUID: aUUID];
}

/* Query example:
SELECT objectUUID, objectVersion, contextVersion FROM (SELECT objectUUID, objectVersion, contextVersion FROM HISTORY WHERE contextUUID = '64dc7e8f-db73-4bcc-666f-d9bf6b77a80a') AS ContextHistory WHERE contextVersion > 2000 ORDER BY contextVersion DESC LIMIT 10 */
- (void) _restoreToVersion: (int)aVersion
{
	_restoringContext = YES;

	NSMutableDictionary *restoredObjectVersions = 
		[self findAllObjectVersionsMatchingContextVersion: aVersion];

	ETDebugLog(@"Will restore objects to versions %@ for registered objects %@", 
		 restoredObjectVersions, _registeredObjects);

	[self discardCurrentObjectsNotYetCreatedAtVersion: aVersion
	                                forObjectVersions: restoredObjectVersions];

	NSSet *mergedObjects = 
		[self restoreObjectsIfNeededForObjectVersions: restoredObjectVersions];

	/* Resolve pending faults

	   Not truly necessary as explained, but this reduces the amount of faults 
	   and connect all the loaded objects in the graph.

	   Most of the faults are resolved when the restored objects get 
	   deserialized, -loadUUID:withName: tries to resolve faults with the help 
	   of the object server, by checking whether an object is already cached for 
	   the given UUID.
	   This won't work in all cases. For example, if an object A has a fault for 
	   an object B, and A is deserialized before B, A will have a pending fault 
	   for B. This problem doesn't occur with restored objects because a
	   reference to another temporal instance B[n-1] will be replaced by the 
	   existing object B[n], then this object will replaced by B[n-1] when 
	   restored.

	   Resolving only faults that refers to merged objects isn't sufficient,
	   because merged objects can themselves have pending faults that refers to 
	   other objects in the cached graph. Hence we don't do...
	   FOREACHI(mergedObjects, mergedObject)
	   	[[self objectServer] resolvePendingFaultsForUUID: [mergedObject UUID]]; */
	[[self objectServer] resolvePendingFaultsWithinCachedObjectGraph];

	[self logRestoreContextVersion: aVersion];

	/* Post notification */
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: COObjectContextDidMergeObjectsNotification
		object: self
		userInfo: D(COMergedObjectsKey, mergedObjects)];

	_restoringContext = NO;
}

/** Returns a context version that isn't a restore point, by looking back for 
    the past version restored on this restore point.
    If aVersion isn't a restore point, returns aVersion as is.
    If aVersion is a restore point, looks up the restored version and checks
    whether it is a restore point or not. If it isn't, returns the found 
    version, otherwise continues the lookup until a version not bound to a 
    restore point is reached. */
- (int) lookUpVersionIfRestorePointAtVersion: (int)aVersion
{
	NSString *query = [NSString stringWithFormat: 
		@"SELECT objectUUID, contextUUID, objectVersion FROM \
			(SELECT objectUUID, contextUUID, objectVersion, contextVersion FROM History \
			 WHERE contextUUID = '%@') AS ContextHistory \
		  WHERE contextVersion = %i;", 
		[[self UUID] stringValue], aVersion];

	PGresult *result = [[self metadataServer] executeRawPGSQLQuery: query];
	[self printQueryResult: result];

	ETUUID *objectUUID = [ETUUID UUIDWithString: 
		[NSString stringWithUTF8String: PQgetvalue(result, 0, 0)]];
	ETUUID *contextUUID = [ETUUID UUIDWithString: 
		[NSString stringWithUTF8String: PQgetvalue(result, 0, 1)]];
	int foundVersion = aVersion;
	BOOL isRestorePoint = [objectUUID isEqual: contextUUID];

	if (isRestorePoint)
	{
		int restoredVersion = atoi(PQgetvalue(result, 0, 2));
		foundVersion = [self lookUpVersionIfRestorePointAtVersion: restoredVersion];
	}

	return foundVersion;
}

/* Collects the object versions to restore at a given context version and 
   returns them in a dictionary keyed by the UUIDs of the matched objects. */
- (NSMutableDictionary *) findAllObjectVersionsMatchingContextVersion: (int)aVersion
{
	int restoredVersion = [self lookUpVersionIfRestorePointAtVersion: aVersion];

	/* Query the global history for the history of the context before aVersion */
	NSString *query = [NSString stringWithFormat: 
		@"SELECT objectUUID, objectVersion, contextVersion FROM \
			(SELECT objectUUID, objectVersion, contextVersion FROM History \
			 WHERE contextUUID = '%@') AS ContextHistory \
		  WHERE contextVersion < %i ORDER BY contextVersion DESC", 
		[[self UUID] stringValue], (restoredVersion + 1)];

	PGresult *result = [[self metadataServer] executeRawPGSQLQuery: query];
	int nbOfRows = PQntuples(result);
	int nbOfCols = PQnfields(result);
	ETUUID *objectUUID = nil;
	int objectVersion = -1;
	int contextVersion = -1;
	/* Collection where the object versions to be restored are put keyed by UUIDs */
	NSMutableDictionary *restoredObjectVersions = [NSMutableDictionary dictionary];

	ETLog(@"Context restore query result: %d rows and %d colums", nbOfRows, nbOfCols);
	[self printQueryResult: result];

	/* Find all the objects to be restored */ 
	for (int row = 0; row < nbOfRows; row++)
	{
		objectUUID = [ETUUID UUIDWithString: 
			[NSString stringWithUTF8String: PQgetvalue(result, row, 0)]];
		objectVersion = atoi(PQgetvalue(result, row, 1));
		contextVersion = atoi(PQgetvalue(result, row, 2));

		BOOL objectNotAlreadyFound = ([[restoredObjectVersions allKeys] containsObject: objectUUID] == NO);

		if (objectNotAlreadyFound)
		{
			[restoredObjectVersions setObject: [NSNumber numberWithInt: objectVersion] 
			                           forKey: objectUUID];
		}

		/* If a past object version has already been found for each registered 
		   object, we already know all the objects to be reverted, hence we 
		   can skip the rest of the earlier history. */
		// FIXME: Test against the number of objects that belong to the context 
		// rather than the number of registered objects since some objects to 
		// be restored may not be loaded at this point. If we scan the 
		// history between the restored version and the current version rather 
		// than before the restored version to 0, we can limit the amount of 
		// work by only considering the objects modified in this timespan.
		//if ([restoredObjectVersions count] == nbOfRegisteredObjects)
		//	break;
	}
	
	/* Free the query result now the object versions are extracted */
	PQclear(result);
	
	return restoredObjectVersions;
}

/* Prints the query result on stdout for debugging. */
- (void) printQueryResult: (PGresult *)result
{
	PQprintOpt options = {0};

	options.header = 1; /* Ask for column headers */
	options.align = 1; /* Pad short columns for alignment */
	options.fieldSep = "|"; /* Use a pipe as the field separator */

	PQprint(stdout, result, &options);
}

/* Discards registered objects not yet created at aVersion.
   The objects are removed from the cached objects by being unregistered. */
- (void) discardCurrentObjectsNotYetCreatedAtVersion: (int)aVersion 
                                   forObjectVersions: (NSDictionary *)restoredObjectVersions
{
	NSArray *restoredUUIDs = [restoredObjectVersions allKeys];

	FOREACHI(_registeredObjects, object)
	{
		BOOL isFutureObject = ([restoredUUIDs containsObject: [object UUID]] == NO);

		if (isFutureObject)
		{
			[self unregisterObject: object];
			ETDebugLog(@"Discard future object %@", object);
		}
	}
}

/* Restores the objects we just found with 
   -findAllObjectVersionsMatchingContextVersion: if they have changed between 
   the restored version and the current version, then merges each restored 
   object in the object context. Finally returns these merged objects. 
   Restored/merged objects are temporal instances that matches the restored 
   context version and replaces their related current instances registered in 
   the context. 
   For each restored object, the restore operation is recorded as a merge in the 
   history of each object by calling -commitMergeOfInstance:forObject:. For a 
   context restore, the merge is simply a raw replacement by taking a snaphot 
   of the restored object. */
- (NSSet *) restoreObjectsIfNeededForObjectVersions: (NSDictionary *)restoredObjectVersions
{
	COObjectServer *objectServer = [self objectServer];
	NSMutableSet *mergedObjects = [NSMutableSet set];

	FOREACHI([restoredObjectVersions allKeys], restoredUUID)
	{
		id currentObject = [objectServer cachedObjectForUUID: restoredUUID];
		// NOTE: We check the object really belongs to the context by safety.
		BOOL objectAlreadyLoaded = (currentObject != nil && [_registeredObjects containsObject: currentObject]);
		int restoredVersion = [[restoredObjectVersions objectForKey: restoredUUID] intValue];
		id restoredObject = nil;

		if (objectAlreadyLoaded) /* Restore an object present in the cache */
		{
			BOOL currentObjectUpToDate = (restoredVersion == [currentObject objectVersion]);

			/* Only restore the objects that have changed between aVersion and 
			   the current context version */
			if (currentObjectUpToDate)
				continue;

			restoredObject = [self objectByRollingbackObject: currentObject 
			                                       toVersion: restoredVersion
			                                mergeImmediately: YES];
			ETLog(@"Restore %@ version %i within %@", restoredObject, restoredVersion, self);
		}
		else /* Restore an object missing from the cache */
		{
			BOOL inStoreObjectUpToDate = (restoredVersion == [self lastObjectVersionForUUID: restoredUUID]);

			/* Only restore the objects that have changed between aVersion and 
			   the current context version */
			if (inStoreObjectUpToDate)
				continue;

			restoredObject = [self objectForUUID: restoredUUID version: restoredVersion];
			ETLog(@"Recreate %@ version %i within %@", restoredObject, restoredVersion, self);
		}

		/* Other objects may refer this object we just restored, however 
		   we don't resolve these pending faults immediately, because other
		   objects yet to be restored may introduce new pending faults for 
		   that object. In other words, more faults may appear if following 
		   restored objects hold a reference on the one we just restored. 
		   Take note that resolving pending faults isn't mandatory because 
		   faults are also resolved on demand (see COGroup). */
		
		[mergedObjects addObject: restoredObject];
	}

	return mergedObjects;
}

/* Logs the restore operation in the global history kept in the metadata 
   server. */
- (void) logRestoreContextVersion: (int)aVersion
{
	_version++;
	[[self metadataServer] executeDBRequest: [NSString stringWithFormat: 
		@"INSERT INTO History (objectUUID, objectVersion, contextUUID, "
		"contextVersion, date) "
		"VALUES ('%@', %i, '%@', %i, '%@');", 
			[_uuid stringValue],
			aVersion,
			[_uuid stringValue],
			_version,
			[NSDate date]]];

	ETDebugLog(@"Log restore context with UUID %@ to version %i as new version %i", 
		 _uuid, aVersion, _version);
}

@end
