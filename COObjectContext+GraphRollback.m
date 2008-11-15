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
- (int) collectObjectVersionsRestoredByContextVersion: (int)aVersion 
                                        inQueryResult: (PGresult *)result
                                               forRow: (int *)aRow
                                       withDictionary: (NSMutableDictionary *)restoredObjectVersions;
- (void) discardCurrentObjectsNotYetCreatedAtVersion: (int)aVersion 
                                   forObjectVersions: (NSDictionary *)restoredObjectVersions;
- (NSSet *) restoreObjectsIfNeededForObjectVersions: (NSDictionary *)restoredObjectVersions;
- (void) logRestoreContextVersion: (int)aVersion;
@end


@implementation COObjectContext (GraphRollback)

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
	if (aVersion >= _version)
	{
		ETLog(@"WARNING: The context %@ cannot be restored to a version equal "
			   "or beyond the current one %i (%i requested).", self, _version, aVersion);
		return;
	}

	_restoringContext = YES;

	 // NOTE: We increment context version right now to ensure 
	// -commitMergeOfInstance:forObject: will log into the history with the 
	// version used to identify the restore point we are on the way to create.
	_version++;

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
    restore point is reached. 
    If a version is invalid, for example it is beyond the current context 
    version, returns -1. */
- (int) lookUpVersionIfRestorePointAtVersion: (int)aVersion
{
	if (aVersion > [self version])
		return -1;

	// NOTE: See -findAllObjectVersionsMatchingContextVersion: doc to understand 
	// why we use the global version in the query.
	NSString *query = [NSString stringWithFormat: 
		@"SELECT objectUUID, contextUUID, objectVersion, globalVersion FROM \
			(SELECT objectUUID, contextUUID, objectVersion, contextVersion, globalVersion FROM History \
			 WHERE contextUUID = '%@') AS ContextHistory \
		  WHERE contextVersion = %i ORDER BY globalVersion DESC;", 
		[[self UUID] stringValue], aVersion];

	PGresult *result = [[self metadataServer] executeRawPGSQLQuery: query];
	//[self printQueryResult: result];

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

	PQclear(result);

	return foundVersion;
}

/* When this macro is defined, the history scanning jumps to the restored 
   context version when a restore point is encountered, and bypass all the 
   history between both. This ensures objects which are inserted/created between 
   these two points in time, hence didn't exist before, won't be restored. In 
   future, this will also make possible to correctly ignore a deletion, if it 
   occurs between a restore point that got traversed and the restored context 
   version associated with it.
   Take note that by default, this algorithm also leverages the list of the restored 
   objects logged in the history for each restore point. This allows to restore 
   the object graph more quickly, see the last paragraph. But a from scratch
   reconstruction of the object graph is possible, if these infos are ignored. 
   A restore from scratch would involve partially restoring each restore point 
   in the list of the restore points that make up the current object graph state.
   (Would be more clear with a diagram that shows how we traverse the history 
   table...)

   If the macro isn't defined, the history scanning is linear and doesn't 
   progress by backward jumps, that bypass parts of the history between a 
   restore point and the restored context version associated with it. However 
   this algorithm only works because we log all the objects that got restored at 
   a restore point. The downside is that it ignores insertion and deletion of
   objects, so some objects may weirdly remain available, by being still cached 
   and registered in the context.

   Logging all restored objects for a restore point isn't really necessary to 
   support context restoration, but has the following advantages:
   - faster context restoration by leveraging the snapshots created by previous 
     context restorations. Context restorations can be an extremly costly 
     operation if you traverse the entire history and recreate all the objects 
     to restore by the mean of invocation playback. This limits the amount of 
     objects for which we need to scan the history and for which many invocations 
     have to be played back. (a detailed analysis with benchmarks will have to 
     be carried out)
   - probably helpful to simplify and maximize the trimming of the history.
     Because each time an object gets restored, all its previous history can 
     potentially be discarded. (think about to be sure)
   - more consistent history, since every object versions appear in the history. 
     The the ones that corresponds to a merge of a restored object aren't implicit
   - convenient to see what is affected by a restore point (useful for debugging
     and inspecting) */
#define REAL_RESTORE_POINT_TRAVERSAL

// NOTE: Update these if you shuffle the order of the fields in the query of 
// -findAllObjectVersionsMatchingContextVersion:
#define OBJECT_UUID_COL 0
#define CTXT_UUID_COL 1
#define OBJECT_VERSION_COL 2
#define CTXT_VERSION_COL 3

/* Collects the object versions to restore at a given context version and 
   returns them in a dictionary keyed by the UUIDs of the matched objects.

   Note: The sorting of the query result is done on the global version rather 
   than the context version because multiple rows are logged with identical
   context version for each restored object at a restore point. If we sort on 
   the context version, we are not sure the row logged by the context for the 
   restore point will be in first position. */
- (NSMutableDictionary *) findAllObjectVersionsMatchingContextVersion: (int)aVersion
{
	if (aVersion > [self version])
		return [NSMutableDictionary dictionary];

	/* Query the global history for the history of the context before aVersion */
	NSString *query = [NSString stringWithFormat: 
		@"SELECT objectUUID, contextUUID, objectVersion, contextVersion, globalVersion FROM \
			(SELECT objectUUID, contextUUID, objectVersion, contextVersion, globalVersion FROM History \
			 WHERE contextUUID = '%@') AS ContextHistory \
		  WHERE contextVersion < %i ORDER BY globalVersion DESC", 
		[[self UUID] stringValue], (aVersion + 1)];

	PGresult *result = [[self metadataServer] executeRawPGSQLQuery: query];
	int nbOfRows = PQntuples(result);
	ETUUID *objectUUID = nil;
	ETUUID *contextUUID = nil;
	int objectVersion = -1;
	int contextVersion = -1;
	int restoredCtxtVersion = -1;
	BOOL isTraversingRestorePoint = NO;
	/* Collection where the object versions to be restored are put keyed by UUIDs */
	NSMutableDictionary *restoredObjectVersions = [NSMutableDictionary dictionary];

	ETDebugLog(@"Restore context %@ with query result: %d rows and %d colums...", self, nbOfRows, nbOfCols);
	//[self printQueryResult: result];

	/* Find all the objects to be restored */ 
	for (int row = 0; row < nbOfRows; row++)
	{
		objectUUID = [ETUUID UUIDWithString: 
			[NSString stringWithUTF8String: PQgetvalue(result, row, OBJECT_UUID_COL)]];
		contextUUID = [ETUUID UUIDWithString: 
			[NSString stringWithUTF8String: PQgetvalue(result, row, CTXT_UUID_COL)]];
		objectVersion = atoi(PQgetvalue(result, row, OBJECT_VERSION_COL));
		contextVersion = atoi(PQgetvalue(result, row, CTXT_VERSION_COL));

#ifdef REAL_RESTORE_POINT_TRAVERSAL

		// TODO: Extract all this #ifdef code in a method to make this clearer
		// or rewrite a bit differently 
		
		/* Skip rows if we are looking for a given context version after 
		   traversing a restore point. */
		if (isTraversingRestorePoint)
		{
			/* Fast backward iteration over the history */
			if (contextVersion != restoredCtxtVersion)
				continue;

			/* Revert to the normal iteration over the history when the restored 
			   version we are looking for is found. */
			isTraversingRestorePoint = NO;
		}

		/* Handle the case where row is a restore point, row variable may be 
		   altered if there are restore rows bound to the restore point, that 
		   have to to be skipped.
		   If we found a restore point, we switch to fast backward iteration 
		   by setting isTraversingRestorePoint to YES.
		   If we don't, row and restoredObjectVersions are let as is by the 
		   method call and we process further to collect the object version from 
		   this message row. */
		restoredCtxtVersion = 
			[self collectObjectVersionsRestoredByContextVersion: contextVersion
			                                      inQueryResult: result 
			                                             forRow: &row 
			                                     withDictionary: restoredObjectVersions];
		if (restoredCtxtVersion != -1)
		{
			/* Row is currently equal to the next context version we want 
			   to inspect, so we must negate the effect of for (;;row++) */
			row--;
			isTraversingRestorePoint = YES;
			continue;
		}

#else

		BOOL isRestorePoint = [objectUUID isEqual: contextUUID];
		if (isRestorePoint)
			continue;

#endif

		NSAssert3([objectUUID isEqual: _uuid] == NO, @"At row %i, restore point "
			@"%i to version %i wrongly matched as a logged message in the history", 
			row, contextVersion, objectVersion);

		/* Collect the current object version if needed */
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

	PQclear(result);

	return restoredObjectVersions;
}

// TODO: Support restore from scratch if a nil dictionary is passed.
- (int) collectObjectVersionsRestoredByContextVersion: (int)aVersion 
                                        inQueryResult: (PGresult *)result
                                               forRow: (int *)aRow
                                       withDictionary: (NSMutableDictionary *)restoredObjectVersions
{
	char *objectUUIDValue = PQgetvalue(result, *aRow, OBJECT_UUID_COL);
	char *contextUUIDValue = PQgetvalue(result, *aRow, CTXT_UUID_COL);
	BOOL isRestorePoint = (strcmp(objectUUIDValue, contextUUIDValue) == 0
		&& aVersion == atoi(PQgetvalue(result, *aRow, CTXT_VERSION_COL)));

	if (isRestorePoint == NO)
		return -1;

	int restoredVersion = atoi(PQgetvalue(result, *aRow, OBJECT_VERSION_COL));
	int nbOfRows = PQntuples(result);
	int row = *aRow + 1; /* aRow + 1 is used to skip the restore point row. */

	for (; row < nbOfRows; row++)
	{
		ETUUID *objectUUID = [ETUUID UUIDWithString: 
			[NSString stringWithUTF8String: PQgetvalue(result, row, OBJECT_UUID_COL)]];
		int objectVersion = atoi(PQgetvalue(result, row, OBJECT_VERSION_COL));
		int contextVersion = atoi(PQgetvalue(result, row, CTXT_VERSION_COL));
		BOOL isRestoreRow = (contextVersion == aVersion);

		if (isRestoreRow == NO)
			break;

		BOOL objectNotAlreadyFound = ([[restoredObjectVersions allKeys] containsObject: objectUUID] == NO);

		if (objectNotAlreadyFound)
		{
			[restoredObjectVersions setObject: [NSNumber numberWithInt: objectVersion] 
			                           forKey: objectUUID];
		}
	}

	/* Expose the restored rows to be skipped to the caller */
	*aRow = row;

	return restoredVersion;
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
			{
				//ETLog(@"Ignore %@ restored version %i within %@", currentObject, restoredVersion, self);
				continue;
			}

			restoredObject = [self objectByRestoringObject: currentObject 
			                                       toVersion: restoredVersion
			                                mergeImmediately: YES];
			ETDebugLog(@"Restore %@ restored version %i", restoredObject, restoredVersion);
		}
		else /* Restore an object missing from the cache */
		{
			BOOL inStoreObjectUpToDate = (restoredVersion == [self lastObjectVersionForUUID: restoredUUID]);

			/* Only restore the objects that have changed between aVersion and 
			   the current context version */
			if (inStoreObjectUpToDate)
			{
				//ETLog(@"Ignore in store %@ restored version %i", restoredUUID, restoredVersion);
				continue;
			}

			restoredObject = [self objectForUUID: restoredUUID version: restoredVersion];
			ETDebugLog(@"Recreate %@ restored version %i within %@", restoredObject, restoredVersion, self);
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
	// NOTE: We don't increment _version here but before in -_restoreToVersion:
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
