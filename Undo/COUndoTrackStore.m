/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "COUndoTrackStore.h"
#import "COUndoTrack.h"
#import <EtoileFoundation/EtoileFoundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "COCommand.h"
#import "CODateSerialization.h"
#import "COEndOfUndoTrackPlaceholderNode.h"
#import "COJSONSerialization.h"
#import "NSDistributedNotificationCenter.h"

NSString * const COUndoTrackStoreTrackDidChangeNotification = @"COUndoTrackStoreTrackDidChangeNotification";
NSString * const COUndoTrackStoreTrackName = @"COUndoTrackStoreTrackName";
NSString * const COUndoTrackStoreTrackHeadCommandUUID = @"COUndoTrackStoreTrackHeadCommandUUID";
NSString * const COUndoTrackStoreTrackCurrentCommandUUID = @"COUndoTrackStoreTrackCurrentCommandUUID";

@implementation COUndoTrackSerializedCommand
@synthesize JSONData, metadata, UUID, parentUUID, trackName, timestamp, sequenceNumber;
@end

@implementation COUndoTrackState
@synthesize trackName, headCommandUUID, currentCommandUUID;
- (id)copyWithZone:(NSZone *)zone
{
	COUndoTrackState *aCopy = [COUndoTrackState new];
	aCopy.trackName = self.trackName;
	aCopy.headCommandUUID = self.headCommandUUID;
	aCopy.currentCommandUUID = self.currentCommandUUID;
	return aCopy;
}
- (BOOL) isEqual:(id)object
{
	if (![object isKindOfClass: [COUndoTrackState class]])
		return NO;
	COUndoTrackState *otherState = object;
	return [self.trackName isEqual: otherState.trackName]
		&& [self.headCommandUUID isEqual: otherState.headCommandUUID]
		&& ((self.currentCommandUUID == nil && otherState.currentCommandUUID == nil)
			|| [self.currentCommandUUID isEqual: otherState.currentCommandUUID]);
}
@end

/*
 
 Points to remember about concurrency:
  - The SQLite database is always in a consistent state. In-memory snapshot
    of the DB may be out of date.
 
 Algorithms
 ----------

 Performing an undo or redo on a track:
   - start a transaction
   - check that the state of the track in the DB matches an in memory snapshot
      - If in-memory snapshot is out of date, the command fails.
   - do something external that is "destructive" (i.e. applying and committing changes to the editing context)
   - update the state in the database
   - commit the transaction.
 
   Since this involves doing something destructive to another database partway
   through the transaction, we have a "point of no return", so we should use
   BEGIN EXCLUSIVE TRANSACTION (see http://sqlite.org/lang_transaction.html ).
 
 Pushing command(s) to a track:
  - start a transaction
  - check that the state of the track in the DB matches an in memory snapshot
    - If in-memory snapshot is out of date, update the snapshot and proceed
      (it doesn't matter if the in memory snapshot was out of date)
  - add the command
  - update the track state
  - commit the transaction
 
 
 Note:
 Commands are immutable, so to check the track state in memory matches what's on disk, 
 all that needs to be compared are the current/head commands.
 
 Note that there is a danger of reaching the "commit the transaction" step, 
 and having the commit fail (even though the corresponding editing context
 change, whether it's applying an undo, redo, or simply making a regular commit,
 has already been committed).
 
 This situation is not ideal... but it's not a disaster. Considering the case when the
 user was performing an undo. The undo would have been saved in the editing context,
 but the undo track would be slightly out of sync (it would not know that the undo was 
 already done.) Both databases are still in a consistent state. 
 Also, as far as I understand, this should be really rare in practice
 ( BEGIN EXCLUSIVE TRANSACTION succeeds, some writes succeed, but the COMMIT fails).
 
 */

@implementation COUndoTrackStore

+ (COUndoTrackStore *) defaultStore
{
    static COUndoTrackStore *store;
    if (store == nil)
    {
        store = [[COUndoTrackStore alloc] init];
    }
    return store;
}

- (id) init
{
    SUPERINIT;
    
	_modifiedTrackStateForTrackName = [NSMutableDictionary new];
	
    NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);

    NSString *dir = [[[libraryDirs objectAtIndex: 0]
                      stringByAppendingPathComponent: @"CoreObject"]
                        stringByAppendingPathComponent: @"Undo"];

    [[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: NULL];
	
    @autoreleasepool {
		_db = [[FMDatabase alloc] initWithPath: [dir stringByAppendingPathComponent: @"undo.sqlite"]];
		[_db setShouldCacheStatements: YES];
		[_db setLogsErrors: YES];
		assert([_db open]);
		
		// Use write-ahead-log mode
		{
			NSString *result = [_db stringForQuery: @"PRAGMA journal_mode=WAL"];
			if (![@"wal" isEqualToString: result])
			{
				NSLog(@"Enabling WAL mode failed.");
			}
		}

		[_db executeUpdate: @"PRAGMA foreign_keys = ON"];
		if (1 != [_db intForQuery: @"PRAGMA foreign_keys"])
		{
			[NSException raise: NSGenericException format: @"Your SQLite version doesn't support foreign keys"];
		}
		
		[_db executeUpdate: @"CREATE TABLE IF NOT EXISTS commands (id INTEGER PRIMARY KEY AUTOINCREMENT, "
							 "uuid BLOB NOT NULL UNIQUE, parentid INTEGER, trackname STRING NOT NULL, data BLOB NOT NULL, "
							 "metadata BLOB, timestamp INTEGER NOT NULL)"];
		
		// NULL currentid means "the start of the track"
		[_db executeUpdate: @"CREATE TABLE IF NOT EXISTS tracks (trackname STRING PRIMARY KEY, "
							 "headid INTEGER NOT NULL, currentid INTEGER, "
							 "FOREIGN KEY(headid) REFERENCES commands(id), "
							 "FOREIGN KEY(currentid) REFERENCES commands(id))"];
	}
    return self;
}

- (void) dealloc
{
    [_db close];
}

- (BOOL) beginTransaction
{
    return [_db executeUpdate: @"BEGIN EXCLUSIVE TRANSACTION"];
}

- (BOOL) commitTransaction
{
    BOOL ok = [_db commit];
	if (ok)
	{
		[self postCommitNotifications];
	}
	return ok;
}

- (NSArray *) trackNames
{
	return [_db arrayForQuery: @"SELECT DISTINCT trackname FROM tracks"];
}

- (NSArray *) trackNamesMatchingGlobPattern: (NSString *)aPattern
{
	return [_db arrayForQuery: @"SELECT DISTINCT trackname FROM tracks WHERE trackname GLOB ?", aPattern];
}

- (COUndoTrackState *) stateForTrackName: (NSString*)aName
{
    FMResultSet *rs = [_db executeQuery: @"SELECT track.trackname, head.uuid AS headuuid, current.uuid AS currentuuid "
										  "FROM tracks AS track "
										  "LEFT OUTER JOIN commands AS head ON track.headid = head.id "
										  "LEFT OUTER JOIN commands AS current ON track.currentid = current.id "
										  "WHERE track.trackname = ?", aName];
	COUndoTrackState *result = nil;
    if ([rs next])
    {
		result = [COUndoTrackState new];
		result.trackName = [rs stringForColumn: @"trackname"];
		result.headCommandUUID = [ETUUID UUIDWithData: [rs dataForColumn: @"headuuid"]];
		result.currentCommandUUID = [rs dataForColumn: @"currentuuid"] != nil
									? [ETUUID UUIDWithData: [rs dataForColumn: @"currentuuid"]]
									: nil;
		
		ETAssert(![result.currentCommandUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
		ETAssert(![result.headCommandUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
    }
    [rs close];
    return result;
}

- (void) setTrackState: (COUndoTrackState *)aState
{
	ETAssert([_db inTransaction]);
	ETAssert(![aState.headCommandUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
	ETAssert(![aState.currentCommandUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
	
	[_db executeUpdate: @"INSERT OR REPLACE INTO tracks (trackname, headid, currentid) "
						@"VALUES (?, (SELECT id FROM commands WHERE uuid = ?), (SELECT id FROM commands WHERE uuid = ?))",
						aState.trackName, [aState.headCommandUUID dataValue], [aState.currentCommandUUID dataValue]];
	_modifiedTrackStateForTrackName[aState.trackName] = [aState copy];
}

- (void) removeTrackWithName: (NSString*)aName
{
	ETAssert([_db inTransaction]);
	[_db executeUpdate: @"DELETE FROM tracks WHERE trackname = ?", aName];
	[_db executeUpdate: @"DELETE FROM commands WHERE trackname = ?", aName];
}

- (NSArray *) allCommandUUIDsOnTrackWithName: (NSString*)aName
{
	return [[_db arrayForQuery: @"SELECT uuid FROM commands WHERE trackname = ?", aName] mappedCollectionWithBlock: ^(id object) {
		return [ETUUID UUIDWithData: object];
	}];
}

- (NSData *) serialize: (id)json
{
	if (json != nil)
		return CODataWithJSONObject(json, NULL);
	return nil;
}

- (id) deserialize: (NSData *)data
{
	if (data != nil)
		return COJSONObjectWithData(data, NULL);
	return nil;
}

- (void) addCommand: (COUndoTrackSerializedCommand *)aCommand
{
	ETAssert(![aCommand.parentUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
	ETAssert(![aCommand.UUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
	
	[_db executeUpdate: @"INSERT INTO commands(uuid, parentid, trackname, data, metadata, timestamp) "
						@"VALUES(?, (SELECT id FROM commands WHERE uuid = ?), ?, ?, ?, ?)",
		[aCommand.UUID dataValue],
		[aCommand.parentUUID dataValue],
		aCommand.trackName,
		[self serialize: aCommand.JSONData],
		[self serialize: aCommand.metadata],
		CODateToJavaTimestamp(aCommand.timestamp)];
	aCommand.sequenceNumber = [_db lastInsertRowId];
}

- (COUndoTrackSerializedCommand *) commandForUUID: (ETUUID *)aUUID
{
    FMResultSet *rs = [_db executeQuery: @"SELECT c.id, parent.uuid AS parentuuid, c.trackname, c.data, c.metadata, c.timestamp "
										  "FROM commands AS c "
										  "LEFT OUTER JOIN commands AS parent ON c.parentid = parent.id "
										  "WHERE c.uuid = ?", [aUUID dataValue]];
	COUndoTrackSerializedCommand *result = nil;
    if ([rs next])
    {
		result = [COUndoTrackSerializedCommand new];
		result.JSONData = [self deserialize: [rs dataForColumn: @"data"]];
		result.metadata = [self deserialize: [rs dataForColumn: @"metadata"]];
		result.UUID = aUUID;
		ETAssert(![result.UUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
		if ([rs dataForColumn: @"parentuuid"] != nil)
		{
			result.parentUUID = [ETUUID UUIDWithData: [rs dataForColumn: @"parentuuid"]];
			ETAssert(![result.parentUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
		}
		result.trackName = [rs stringForColumn: @"trackname"];
		result.timestamp = CODateFromJavaTimestamp([rs numberForColumn: @"timestamp"]);
		result.sequenceNumber = [rs longForColumn: @"id"];
    }
    [rs close];
    return result;
}

- (void) removeCommandForUUID: (ETUUID *)aUUID
{
	[_db executeUpdate: @"DELETE FROM commands WHERE uuid = ?", [aUUID dataValue]];
}

- (BOOL) string: (NSString *)aString matchesGlobPattern: (NSString *)aPattern
{
	return [_db boolForQuery: @"SELECT 1 WHERE ? GLOB ?", aString, aPattern];
}

- (void) postCommitNotificationsWithUserInfo: (NSDictionary *)userInfo
{
	ETAssert([NSThread isMainThread]);
	
	[[NSNotificationCenter defaultCenter] postNotificationName: COUndoTrackStoreTrackDidChangeNotification
	                                                    object: self
	                                                  userInfo: userInfo];

	[[NSDistributedNotificationCenter defaultCenter]
	 postNotificationName: COUndoTrackStoreTrackDidChangeNotification
	 object: [_db databasePath]
	 userInfo: userInfo
	 deliverImmediately: YES];
}

- (void) postCommitNotifications
{
	for (NSString *modifiedTrack in _modifiedTrackStateForTrackName)
	{
		COUndoTrackState *state = _modifiedTrackStateForTrackName[modifiedTrack];
		
		id currentUUIDString = state.currentCommandUUID != nil
			? [state.currentCommandUUID stringValue]
			: [NSNull null];
		
		NSDictionary *userInfo = @{COUndoTrackStoreTrackName : modifiedTrack,
								   COUndoTrackStoreTrackHeadCommandUUID : [state.headCommandUUID stringValue],
								   COUndoTrackStoreTrackCurrentCommandUUID : currentUUIDString};
		[self postCommitNotificationsWithUserInfo: userInfo];
		
	}
	[_modifiedTrackStateForTrackName removeAllObjects];
}

@end
