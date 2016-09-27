/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "COUndoTrackStore.h"
#import "COUndoTrackStore+Private.h"
#import "COUndoTrack.h"
#import <EtoileFoundation/EtoileFoundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "COCommand.h"
#import "CODateSerialization.h"
#import "COEndOfUndoTrackPlaceholderNode.h"
#import "COJSONSerialization.h"
#import "COSQLiteUtilities.h"
#if TARGET_OS_IPHONE
#import "NSDistributedNotificationCenter.h"
#endif

/* For dispatch_get_current_queue() deprecated on iOS (to prevent to people to 
   use it beside debugging) */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

NSString * const COUndoTrackStoreTrackDidChangeNotification = @"COUndoTrackStoreTrackDidChangeNotification";
NSString * const COUndoTrackStoreTrackName = @"COUndoTrackStoreTrackName";
NSString * const COUndoTrackStoreTrackHeadCommandUUID = @"COUndoTrackStoreTrackHeadCommandUUID";
NSString * const COUndoTrackStoreTrackCurrentCommandUUID = @"COUndoTrackStoreTrackCurrentCommandUUID";
NSString * const COUndoTrackStoreTrackCompacted = @"COUndoTrackStoreTrackCompacted";

@implementation COUndoTrackSerializedCommand
@synthesize JSONData, metadata, UUID, parentUUID, trackName, timestamp, sequenceNumber;
@end

@implementation COUndoTrackState
@synthesize trackName, headCommandUUID, currentCommandUUID, compacted;
- (id)copyWithZone:(NSZone *)zone
{
    COUndoTrackState *aCopy = [COUndoTrackState new];
    aCopy.trackName = self.trackName;
    aCopy.headCommandUUID = self.headCommandUUID;
    aCopy.currentCommandUUID = self.currentCommandUUID;
    aCopy.compacted = self.compacted;
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
            || [self.currentCommandUUID isEqual: otherState.currentCommandUUID])
        && self.compacted == otherState.compacted;
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

@synthesize URL = _URL;

+ (NSURL *)defaultStoreURL
{
    NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);

    return [NSURL fileURLWithPath: [[libraryDirs[0] stringByAppendingPathComponent: @"CoreObject"]
        stringByAppendingPathComponent: @"Undo"]];
}

+ (instancetype)defaultStore
{
    static COUndoTrackStore *store;
    if (store == nil)
    {
        store = [[COUndoTrackStore alloc] initWithURL: [self defaultStoreURL]];
    }
    return store;
}

- (instancetype)initWithURL: (NSURL *)aURL
{
    NILARG_EXCEPTION_TEST(aURL);
    INVALIDARG_EXCEPTION_TEST(aURL, aURL.isFileURL);
    SUPERINIT;

    _URL = aURL;
    _modifiedTrackStateForTrackName = [NSMutableDictionary new];
    _queue = dispatch_queue_create([NSString stringWithFormat: @"COUndoTrackStore-%p", self].UTF8String, NULL);
    _transactionLock = dispatch_semaphore_create(1);

    __block BOOL ok = YES;
    
    dispatch_sync(_queue, ^() {
        // Ignore if this fails (it will fail if the directory already exists).
        // If it really fails, we will notice later when we try to open the db.
        [[NSFileManager defaultManager] createDirectoryAtPath: _URL.path
                                  withIntermediateDirectories: YES
                                                   attributes: nil
                                                        error: NULL];
        
        _db = [[FMDatabase alloc] initWithPath: [aURL.path stringByAppendingPathComponent: @"undo.sqlite"]];
        [_db setShouldCacheStatements: YES];
        [_db setCrashOnErrors: NO];
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

        ok = [self setupSchema];
    });

    if (!ok)
    {
        return nil;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithURL: nil];
}

- (void) dealloc
{
    assert(dispatch_get_current_queue() != _queue);
    
    dispatch_sync(_queue, ^() {
        [_db close];
    });
    
#if !(TARGET_OS_IPHONE)
    // N.B.: We are using deployment target 10.7, so ARC does not manage libdispatch objects.
    // If we switch to deployment target 10.8, ARC will manage libdispatch objects automatically.
    // For GNUstep, ARC doesn't manage libdispatch objects since libobjc2 doesn't support it 
    // currently (we compile CoreObject with -DOS_OBJECT_USE_OBJC=0).
    dispatch_release(_queue);
    dispatch_release(_transactionLock);
#endif
}

- (BOOL) setupSchema
{
    assert(dispatch_get_current_queue() == _queue);

    /* SQLite compatibility */
    
    [_db executeUpdate: @"PRAGMA foreign_keys = ON"];
    if (1 != [_db intForQuery: @"PRAGMA foreign_keys"])
    {
        [NSException raise: NSGenericException
                    format: @"Your SQLite version doesn't support foreign keys"];
    }
    
    [_db beginDeferredTransaction];

    /* Store Metadata table (including schema version) */

    if (![_db tableExists: @"storeMetadata"])
    {
        [_db executeUpdate: @"CREATE TABLE storeMetadata(version INTEGER)"];
        [_db executeUpdate: @"INSERT INTO storeMetadata VALUES(1)"];
    }
    else
    {
        int version = [_db intForQuery: @"SELECT version FROM storeMetadata"];
        if (1 != version)
        {
            NSLog(@"Error, undo track store version %d, only version 1 is supported", version);
            [_db rollback];
            return NO;
        }
    }
    
    /* Commands and Tracks tables */
    
    [_db executeUpdate: @"CREATE TABLE IF NOT EXISTS commands (id INTEGER PRIMARY KEY AUTOINCREMENT, "
                         "uuid BLOB NOT NULL UNIQUE, parentid INTEGER, trackname STRING NOT NULL, data BLOB NOT NULL, "
                         "metadata BLOB, timestamp INTEGER NOT NULL, deleted BOOLEAN DEFAULT 0)"];
    
    // NULL currentid means "the start of the track"
    [_db executeUpdate: @"CREATE TABLE IF NOT EXISTS tracks (trackname STRING PRIMARY KEY, "
                         "headid INTEGER NOT NULL, currentid INTEGER, "
                         "FOREIGN KEY(headid) REFERENCES commands(id), "
                         "FOREIGN KEY(currentid) REFERENCES commands(id))"];

    [_db commit];
    
    if ([_db hadError])
    {
        NSLog(@"Error %d: %@", [_db lastErrorCode], [_db lastErrorMessage]);
        return NO;
    }
    return YES;
}

- (void)clearStore
{
    dispatch_sync(_queue, ^() {
        [_db beginTransaction];
        
        [_db executeUpdate: @"DELETE FROM tracks"];
        [_db executeUpdate: @"DELETE FROM commands"];
        [_db executeUpdate: @"DROP TABLE IF EXISTS storeMetadata"];
        [_db commit];
        
        [_modifiedTrackStateForTrackName removeAllObjects];
        
        [self setupSchema];
    });
}

- (BOOL) beginTransaction
{
    ETAssert([NSThread isMainThread]);

    // If there is a background operation (e.g. mark as deleted, vacuum) underway,
    // wait until it is finished
    dispatch_semaphore_wait(_transactionLock, DISPATCH_TIME_FOREVER);

    __block BOOL ok = NO;

    @try {
        dispatch_sync(_queue, ^() {
            ok = [_db beginTransaction];
        });
    } @finally {
        if (!ok)
        {
            dispatch_semaphore_signal(_transactionLock);
        }
    }
    return ok;
}

- (BOOL) commitTransaction
{
    ETAssert([NSThread isMainThread]);
    __block BOOL ok = NO;

    dispatch_sync(_queue, ^() {
        ok = [_db commit];
    });

    if (ok)
    {
        [self postCommitNotifications];
    }
    dispatch_semaphore_signal(_transactionLock);
    return ok;
}

- (NSArray *) trackNames
{
    __block NSArray *result = nil;
    assert(dispatch_get_current_queue() != _queue);
    
    dispatch_sync(_queue, ^() {
        result = [_db arrayForQuery: @"SELECT DISTINCT trackname FROM tracks"];
    });
    return result;
}

- (NSArray *) trackNamesMatchingGlobPattern: (NSString *)aPattern
{
    __block NSArray *result = nil;
    assert(dispatch_get_current_queue() != _queue);
    
    dispatch_sync(_queue, ^() {
        result = [_db arrayForQuery: @"SELECT DISTINCT trackname FROM tracks WHERE trackname GLOB ?", aPattern];
    });
    return result;
}

/**
 * If all commands have been marked as deleted on the track, returns a track 
 * state where head and current commands are both nil.
 */
- (COUndoTrackState *)stateForTrackNameInCurrentQueue: (NSString *)aName
{
    assert(dispatch_get_current_queue() == _queue);

    COUndoTrackState *result = nil;
    FMResultSet *rs = [_db executeQuery:
        @"SELECT track.trackname, head.uuid AS headuuid, current.uuid AS currentuuid, head.deleted AS headdeleted, current.deleted AS currentdeleted "
         "FROM tracks AS track "
         "LEFT OUTER JOIN commands AS head ON track.headid = head.id "
         "LEFT OUTER JOIN commands AS current ON track.currentid = current.id "
         "WHERE track.trackname = ? AND headdeleted = 0", aName];

    result = [COUndoTrackState new];
    result.trackName = aName;

    if ([rs next])
    {
        ETAssert([result.trackName isEqual: [rs stringForColumn: @"trackname"]]);

        result.headCommandUUID = [ETUUID UUIDWithData: [rs dataForColumn: @"headuuid"]];
        if ([rs dataForColumn: @"currentuuid"] != nil && ![rs boolForColumn: @"currentdeleted"])
        {
            result.currentCommandUUID = [ETUUID UUIDWithData: [rs dataForColumn: @"currentuuid"]];
        }
        else
        {
            result.currentCommandUUID = nil;
        }
        
        ETAssert(![result.currentCommandUUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);
        ETAssert(![result.headCommandUUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);
    }
    [rs close];

    return result;
}

- (COUndoTrackState *) stateForTrackName: (NSString*)aName
{
    __block COUndoTrackState *result = nil;
    assert(dispatch_get_current_queue() != _queue);
    
    dispatch_sync(_queue, ^() {
        result = [self stateForTrackNameInCurrentQueue: aName];
    });

    return result;
}

- (void) setTrackState: (COUndoTrackState *)aState
{
    assert(dispatch_get_current_queue() != _queue);
    ETAssert([NSThread isMainThread]);
    ETAssert(![aState.headCommandUUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);
    ETAssert(![aState.currentCommandUUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);
    
    dispatch_sync(_queue, ^() {
        ETAssert([_db inTransaction]);

        [_db executeUpdate: @"INSERT OR REPLACE INTO tracks (trackname, headid, currentid) "
                            @"VALUES (?, (SELECT id FROM commands WHERE uuid = ?),"
                                       @"(SELECT id FROM commands WHERE uuid = ?))",
            aState.trackName, [aState.headCommandUUID dataValue], [aState.currentCommandUUID dataValue]];
    });

    _modifiedTrackStateForTrackName[aState.trackName] = [aState copy];
}

- (void) removeTrackWithName: (NSString*)aName
{
    assert(dispatch_get_current_queue() != _queue);

    dispatch_sync(_queue, ^() {
        ETAssert([_db inTransaction]);

        [_db executeUpdate: @"DELETE FROM tracks WHERE trackname = ?", aName];
        [_db executeUpdate: @"DELETE FROM commands WHERE trackname = ?", aName];
    });
}

- (NSArray *) allCommandUUIDsOnTrackWithName: (NSString*)aName
{
    __block NSArray *result = nil;
    assert(dispatch_get_current_queue() != _queue);
    
    dispatch_sync(_queue, ^() {
        result = [[_db arrayForQuery: @"SELECT uuid FROM commands WHERE trackname = ? and deleted = 0", aName] mappedCollectionWithBlock: ^(id object) { return [ETUUID UUIDWithData: object]; }];
    });
    return result;
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
    assert(dispatch_get_current_queue() != _queue);
    ETAssert(![aCommand.parentUUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);
    ETAssert(![aCommand.UUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);
    
    __block int64_t rowid = -1;
    
    dispatch_sync(_queue, ^() {
        [_db executeUpdate: @"INSERT INTO commands(uuid, parentid, trackname, data, metadata, timestamp) "
                            @"VALUES(?, (SELECT id FROM commands WHERE uuid = ?), ?, ?, ?, ?)",
                            [aCommand.UUID dataValue],
                            [aCommand.parentUUID dataValue],
                            aCommand.trackName,
                            [self serialize: aCommand.JSONData],
                            [self serialize: aCommand.metadata],
                            CODateToJavaTimestamp(aCommand.timestamp)];
    
        rowid = [_db lastInsertRowId];
    });
     
    aCommand.sequenceNumber = rowid;
}

- (COUndoTrackSerializedCommand *) commandForUUID: (ETUUID *)aUUID
{
    assert(dispatch_get_current_queue() != _queue);
    __block COUndoTrackSerializedCommand *result = nil;

    dispatch_sync(_queue, ^() {
        FMResultSet *rs = [_db executeQuery:
            @"SELECT c.id, parent.uuid AS parentuuid, c.trackname, c.data, c.metadata, c.timestamp "
             "FROM commands AS c "
             "LEFT OUTER JOIN commands AS parent ON c.parentid = parent.id "
             "WHERE c.uuid = ? and c.deleted = 0", [aUUID dataValue]];


        if ([rs next])
        {
            result = [COUndoTrackSerializedCommand new];

            result.JSONData = [self deserialize: [rs dataForColumn: @"data"]];
            result.metadata = [self deserialize: [rs dataForColumn: @"metadata"]];
            result.UUID = aUUID;
            ETAssert(![result.UUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);

            if ([rs dataForColumn: @"parentuuid"] != nil)
            {
                result.parentUUID = [ETUUID UUIDWithData: [rs dataForColumn: @"parentuuid"]];
                ETAssert(![result.parentUUID isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance].UUID]);
            }

            result.trackName = [rs stringForColumn: @"trackname"];
            result.timestamp = CODateFromJavaTimestamp([rs numberForColumn: @"timestamp"]);
            result.sequenceNumber = [rs longForColumn: @"id"];
        }
        [rs close];
    });

    return result;
}

- (void) removeCommandForUUID: (ETUUID *)aUUID
{
    assert(dispatch_get_current_queue() != _queue);
    
    dispatch_sync(_queue, ^() {
        [_db executeUpdate: @"DELETE FROM commands WHERE uuid = ?", [aUUID dataValue]];
    });
}

- (BOOL) string: (NSString *)aString matchesGlobPattern: (NSString *)aPattern
{
    assert(dispatch_get_current_queue() != _queue);
    __block BOOL result = NO;

    dispatch_sync(_queue, ^() {
        result = [_db boolForQuery: @"SELECT 1 WHERE ? GLOB ?", aString, aPattern];
    });
    
    return result;
}

- (void)markCommandsAsDeletedForUUIDs: (NSArray *)UUIDs
{
    assert(dispatch_get_current_queue() != _queue);

    // If there is a transaction underway, wait until it is finished
    dispatch_semaphore_wait(_transactionLock, DISPATCH_TIME_FOREVER);

    @try
    {
        __block NSArray *compactedTrackNames = nil;
        // This can be run in background
        dispatch_sync(_queue, ^() {
            [_db beginTransaction];

            for (ETUUID *UUID in UUIDs)
            {
                [_db executeUpdate: @"UPDATE commands SET deleted = 1 WHERE uuid = ?", [UUID dataValue]];
            }

            compactedTrackNames =
            [_db arrayForQuery: @"SELECT DISTINCT trackname FROM commands WHERE deleted = 1 "];

            [_db commit];
        });

        /* This must be run in the main thread:
         - no one must access _modifiedTrackStateForTrackName at the same time
         - we must post the commit notification immediately

         If we post it with some delay, someone could touch
         _modifiedTrackStateForTrackName and overwrite COUndoTrackState.compacted. */
        dispatch_sync_now(dispatch_get_main_queue(), ^() {
            dispatch_sync(_queue, ^() {
                [_db beginTransaction];

                for (NSString *trackName in compactedTrackNames)
                {
                    if (_modifiedTrackStateForTrackName[trackName] == nil)
                    {
                        _modifiedTrackStateForTrackName[trackName] = [self stateForTrackNameInCurrentQueue: trackName];
                    }
                    ((COUndoTrackState *)_modifiedTrackStateForTrackName[trackName]).compacted = YES;
                }

                [_db commit];
            });

            [self postCommitNotifications];
        });
    }
    @finally
    {
        dispatch_semaphore_signal(_transactionLock);
    }
}

- (void)finalizeDeletions
{
    assert(dispatch_get_current_queue() != _queue);

    // If there is a transaction underway, wait until it is finished
    dispatch_semaphore_wait(_transactionLock, DISPATCH_TIME_FOREVER);
    @try
    {
        dispatch_sync(_queue, ^() {
            NSArray *compactedTrackNames =
                [_db arrayForQuery: @"SELECT DISTINCT trackname FROM commands WHERE deleted = 1 "];
            
            for (NSString *trackName in compactedTrackNames)
            {
                if (_modifiedTrackStateForTrackName[trackName] == nil)
                {
                    _modifiedTrackStateForTrackName[trackName] = [self stateForTrackNameInCurrentQueue: trackName];
                }
                
                /* When we compact up to the head, we delete all commands
                   between head and tail including divergent ones, this means
                   the track becomes empty. */
                BOOL isEmptyTrack = ([_modifiedTrackStateForTrackName[trackName] headCommandUUID] == nil);
                
                if (isEmptyTrack)
                {
                    [_db executeUpdate: @"DELETE FROM tracks WHERE trackname = ?", trackName];
                    /* If the head was moved back to the past just before the
                       compaction, then any divergent commands more recent than
                       the head won't be marked as deleted. */
                    [_db executeUpdate: @"DELETE FROM commands WHERE trackname = ?", trackName];
                }
                else
                {
                    BOOL currentMarkedAsDeleted =
                        ([_modifiedTrackStateForTrackName[trackName] currentCommandUUID] == nil);

                    if (currentMarkedAsDeleted)
                    {
                        [_db executeUpdate: @"UPDATE tracks SET currentid = NULL WHERE trackname = ?", trackName];
                    }
                    [_db executeUpdate: @"DELETE FROM commands WHERE deleted = 1"];
                    
                }
            }
        });
    }
    @finally
    {
        dispatch_semaphore_signal(_transactionLock);
    }
}

/**
 * We run vacuum with dispatch_sync() in a queue, so we can sure no other
 * threads access the database when we invoke -vacuum in a background thread.
 */
- (BOOL)vacuum
{
    assert(dispatch_get_current_queue() != _queue);
    __block BOOL success = NO;

    // If there is a transaction underway, wait until it is finished
    dispatch_semaphore_wait(_transactionLock, DISPATCH_TIME_FOREVER);
    @try
    {
        dispatch_sync(_queue, ^() {
            success = [_db executeUpdate: @"VACUUM"];
        });
    }
    @finally
    {
        dispatch_semaphore_signal(_transactionLock);
    }
    return success;
}

- (NSDictionary *)pageStatistics
{
    assert(dispatch_get_current_queue() != _queue);
    __block NSDictionary *statistics = nil;

    dispatch_sync(_queue, ^() {
        statistics = pageStatisticsForDatabase(_db);
    });
    
    return statistics;
}

- (void) postCommitNotificationsWithUserInfo: (NSDictionary *)userInfo
{
    ETAssert([NSThread isMainThread]);
    ETAssert([NSPropertyListSerialization propertyList: userInfo
                                      isValidForFormat: NSPropertyListXMLFormat_v1_0]);

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
        NSMutableDictionary *userInfo = [NSMutableDictionary new];
  
        userInfo[COUndoTrackStoreTrackName] = modifiedTrack;
        if (state.headCommandUUID != nil)
        {
            userInfo[COUndoTrackStoreTrackHeadCommandUUID] = [state.headCommandUUID stringValue];
        }
        if (state.currentCommandUUID != nil)
        {
            userInfo[COUndoTrackStoreTrackCurrentCommandUUID] = [state.currentCommandUUID stringValue];
        }
        userInfo[COUndoTrackStoreTrackCompacted] = @(state.compacted);

        [self postCommitNotificationsWithUserInfo: userInfo];
        
    }
    [_modifiedTrackStateForTrackName removeAllObjects];
}

@end
