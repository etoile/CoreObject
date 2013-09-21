#import "COSQLiteStore.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "CORevisionID.h"
#import "CORevisionInfo.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>

#import "COItem.h"
#import "COSQLiteStore+Attachments.h"
#import "COSearchResult.h"
#import "COBranchInfo.h"
#import "COPersistentRootInfo.h"
#import "COStoreTransaction.h"
#import "COStoreAction.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface COSQLiteStore (AttachmentsPrivate)

- (NSArray *) attachments;
- (BOOL) deleteAttachment: (NSData *)hash;

@end

@implementation COSQLiteStore

@synthesize transactionUUID;

- (id)initWithURL: (NSURL*)aURL
{
	SUPERINIT;
    
    queue_ = dispatch_queue_create([[NSString stringWithFormat: @"COSQLiteStore-%p", self] UTF8String], NULL);
    
	url_ = aURL;
	backingStores_ = [[NSMutableDictionary alloc] init];
    backingStoreUUIDForPersistentRootUUID_ = [[NSMutableDictionary alloc] init];
    modifiedPersistentRootsUUIDs_ = [[NSMutableSet alloc] init];
    	
    __block BOOL ok = YES;
    
    dispatch_sync(queue_, ^() {
        // Ignore if this fails (it will fail if the directory already exists.)
        // If it really fails, we will notice later when we try to open the sqlite db
        [[NSFileManager defaultManager] createDirectoryAtPath: [url_ path]
                                  withIntermediateDirectories: YES
                                                   attributes: nil
                                                        error: NULL];
        
        db_ = [[FMDatabase alloc] initWithPath: [[url_ path] stringByAppendingPathComponent: @"index.sqlite"]];
        
        [db_ setShouldCacheStatements: YES];
        [db_ setCrashOnErrors: NO];
        [db_ setLogsErrors: YES];
        
        [db_ open];
        
        // Use write-ahead-log mode
        {
            NSString *result = [db_ stringForQuery: @"PRAGMA journal_mode=WAL"];
            
            if (![@"wal" isEqualToString: result])
            {
                NSLog(@"Enabling WAL mode failed.");
            }
        }
        
        // Set up schema
        
        [db_ beginDeferredTransaction];
        
        /* Store Metadata tables (including schema version) */
        
        if (![db_ tableExists: @"storeMetadata"])
        {
            _uuid =  [ETUUID UUID];
            [db_ executeUpdate: @"CREATE TABLE storeMetadata(version INTEGER, uuid BLOB)"];
            [db_ executeUpdate: @"INSERT INTO storeMetadata VALUES(1, ?)", [_uuid dataValue]];
        }
        else
        {
            int version = [db_ intForQuery: @"SELECT version FROM storeMetadata"];
            if (1 != version)
            {
                NSLog(@"Error, store version %d, only version 1 is supported", version);
                [db_ rollback];
                ok = NO;
                return;
            }
            
            _uuid =  [ETUUID UUIDWithData: [db_ dataForQuery: @"SELECT uuid FROM storeMetadata"]];
        }
        
        // Persistent Root and Branch tables
        
        [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS persistentroots ("
         "uuid BLOB PRIMARY KEY NOT NULL, backingstore BLOB NOT NULL, "
         "currentbranch BLOB, deleted BOOLEAN DEFAULT 0, transactionuuid BLOB)"];
        
        [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS branches (uuid BLOB NOT NULL PRIMARY KEY, "
         "proot BLOB NOT NULL, initial_revid BLOB NOT NULL, current_revid BLOB NOT NULL, "
         "metadata BLOB, deleted BOOLEAN DEFAULT 0, parentbranch BLOB)"];
        
        // FTS indexes & reference caching tables (in theory, could be regenerated - although not supported)
        
        /**
         * In embedded_object_uuid in revid of backing store root_id, there was a reference to dest_root_id
         */
        [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS proot_refs (root_id BLOB, revid BOLB, embedded_object_uuid BLOB, dest_root_id BLOB)"];
        [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS attachment_refs (root_id BLOB, revid BLOB, attachment_hash BLOB)"];
        
        // FIXME: This is a bit ugly. Verify that usage is consistent across fts3/4
        if (sqlite3_libversion_number() >= 3007011)
        {
            [db_ executeUpdate: @"CREATE VIRTUAL TABLE IF NOT EXISTS fts USING fts4(content=\"\", text)"]; // implicit column docid
        }
        else
        {
            if (nil == [db_ stringForQuery: @"SELECT name FROM sqlite_master WHERE type = 'table' and name = 'fts'"])
            {
                [db_ executeUpdate: @"CREATE VIRTUAL TABLE fts USING fts3(text)"]; // implicit column docid
            }
        }
        
        [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS fts_docid_to_revisionid ("
         "docid INTEGER PRIMARY KEY, backingstore BLOB, revid BLOB)"];
        
        [db_ commit];
        
        if ([db_ hadError])
        {
            NSLog(@"Error %d: %@", [db_ lastErrorCode], [db_ lastErrorMessage]);
            ok = NO;
            return;
        }

    });
    
    if (!ok)
    {
        return nil;
    }
    
	return self;
}


- (NSURL*)URL
{
	return url_;
}

@synthesize UUID = _uuid;

/** @taskunit Transactions */

- (BOOL) beginTransactionWithError: (NSError **)error
{
    [modifiedPersistentRootsUUIDs_ removeAllObjects];
    
    transaction_ = [[COStoreTransaction alloc] init];
    self.transactionUUID = transaction_.transactionUUID;
    
    return YES;
}

- (BOOL) commitTransactionWithError: (NSError **)error
{
    return [self commitTransactionWithUUID: [ETUUID UUID] withError: error];
}

- (BOOL) commitStoreTransaction: (COStoreTransaction *)aTransaction
{
    __block BOOL ok = YES;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^() {
        [db_ beginTransaction];
        
        self.transactionUUID = aTransaction.transactionUUID;
        
        // update the last transaction field before we commit.
        
        for (ETUUID *modifiedUUID in modifiedPersistentRootsUUIDs_)
        {
            [db_ executeUpdate: @"UPDATE persistentroots SET transactionuuid = ? WHERE uuid = ?", [transactionUUID dataValue], [modifiedUUID dataValue]];
        }
        
        

        for (id<COStoreAction> op in aTransaction.operations)
        {
            BOOL opOk = [op execute: self];
            if (!opOk)
            {
                NSLog(@"store action failed: %@", op);
                [op execute: self];
            }
            ok = ok && opOk;
        }
        
        if (!ok)
        {
            [db_ rollback];
            ok = NO;
        }
        else
        {
            ok = [db_ commit];
            if (ok)
            {
                [self postCommitNotificationsForTransaction: transactionUUID];
            }
            else
            {
                NSLog(@"Commit failed");
            }
        }
        
        self.transactionUUID = nil;
    });
    
    return ok;
}

- (BOOL) commitTransactionWithUUID: (ETUUID *)uuid withError: (NSError **)error
{
    return [self commitStoreTransaction: transaction_];
}

- (void) recordModifiedPersistentRoot: (ETUUID *)persistentRootUUID
{
    [modifiedPersistentRootsUUIDs_ addObject: persistentRootUUID];
}

- (void) checkInTransaction
{
    assert(transaction_ != nil);
}

- (NSArray *) allBackingUUIDs
{
    NSMutableArray *result = [NSMutableArray array];
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT DISTINCT backingstore FROM persistentroots"];
        sqlite3_stmt *statement = [[rs statement] statement];
        
        while ([rs next])
        {
            const void *data = sqlite3_column_blob(statement, 0);
            const int dataSize = sqlite3_column_bytes(statement, 0);
          
            assert(dataSize == 16);
            
            ETUUID *uuid = [[ETUUID alloc] initWithUUID: data];
            [result addObject: uuid];
        }
        [rs close];
    });
    
    return result;
}

- (CORevisionID *) revisionIDForRevisionUUID: (ETUUID *)aRevisionUUID
                          persistentRootUUID: (ETUUID *)aPersistentRoot
{
    __block ETUUID *backingUUID;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        backingUUID = [self backingUUIDForPersistentRootUUID: aPersistentRoot];
    });
    
    return [CORevisionID revisionWithPersistentRootUUID: backingUUID
                                        revisionUUID: aRevisionUUID];
}

- (ETUUID *)currentRevisionUUIDForBranchUUID: (ETUUID *)aBranchUUID
{
	NILARG_EXCEPTION_TEST(aBranchUUID);

    __block ETUUID *prootUUID = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT current_revid FROM branches WHERE uuid = ?",
            [aBranchUUID dataValue]];

        if ([rs next])
        {
            prootUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            ETAssert([rs next] == NO);
        }

        [rs close];
    });
                  
	return prootUUID;
}

- (NSArray *)revisionInfosForBranchUUID: (ETUUID *)aBranchUUID
                                options: (COBranchRevisionReadingOptions)options
{
	ETUUID *prootUUID = [self persistentRootUUIDForBranchUUID: aBranchUUID];
	ETUUID *currentRevUUID = [self currentRevisionUUIDForBranchUUID: aBranchUUID];

    __block NSArray *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backingStore =
		[self backingStoreForPersistentRootUUID: prootUUID];

        result = [backingStore revisionInfosForBranchUUID: aBranchUUID
                                         headRevisionUUID: currentRevUUID
                                                  options: options];
    });
    
    return result;
}

- (ETUUID *) backingUUIDForPersistentRootUUID: (ETUUID *)aUUID
{
    assert(dispatch_get_current_queue() == queue_);
    
    ETUUID *backingUUID = [backingStoreUUIDForPersistentRootUUID_ objectForKey: aUUID];
    if (backingUUID == nil)
    {
        NSData *data = [db_ dataForQuery: @"SELECT backingstore FROM persistentroots WHERE uuid = ?", [aUUID dataValue]];
        if (data != nil)
        {
            backingUUID = [ETUUID UUIDWithData: data];
        }
        else
        {
            // HACK
            backingUUID = aUUID;
            //[NSException raise: NSInvalidArgumentException format: @"persistent root %@ not found", aUUID];
        }
        
        [backingStoreUUIDForPersistentRootUUID_ setObject: backingUUID forKey: aUUID];
    }
    return backingUUID;
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForPersistentRootUUID: (ETUUID *)aUUID
{
    assert(dispatch_get_current_queue() == queue_);
    
    return [self backingStoreForUUID: [self backingUUIDForPersistentRootUUID: aUUID]
                               error: NULL];
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForUUID: (ETUUID *)aUUID error: (NSError **)error
{
    COSQLiteStorePersistentRootBackingStore *result = [backingStores_ objectForKey: aUUID];
    if (result == nil)
    {
        result = [[COSQLiteStorePersistentRootBackingStore alloc] initWithPersistentRootUUID: aUUID store: self useStoreDB: NO error: error];
        if (result == nil)
        {
            return nil;
        }
        
        [backingStores_ setObject: result forKey: aUUID];
    }
    return result;
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForRevisionID: (CORevisionID *)aToken
{
    return [self backingStoreForPersistentRootUUID: [aToken revisionPersistentRootUUID]];
}

// FIXME: Implement this method for removing empty backing stores.
// Currently the "furtherst" you can delete a persistent root leaves an
// empty backing store (the SQLite DB should have zero rows)
- (void) deleteBackingStoreWithUUID: (ETUUID *)aUUID
{
    ETAssertUnreachable();
//    {
//        COSQLiteStorePersistentRootBackingStore *backing = [backingStores_ objectForKey: aUUID];
//        if (backing != nil)
//        {
//            [backing close];
//            [backingStores_ removeObjectForKey: aUUID];
//        }
//    }
//    
//    // FIXME: This doesn't appear to ever be tested
//    
//    assert([[NSFileManager defaultManager] removeItemAtPath:
//            [self backingStorePathForUUID: aUUID] error: NULL]);
}

/** @taskunit reading states */

- (CORevisionInfo *) revisionInfoForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
   
    __block CORevisionInfo *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
        result = [backing revisionForID: aToken];
    });
    
    return result;
}

- (COItemGraph *) partialItemGraphFromRevisionID: (CORevisionID *)baseRevid
                                    toRevisionID: (CORevisionID *)finalRevid
{
    NSParameterAssert(baseRevid != nil);
    NSParameterAssert(finalRevid != nil);
    
    __block COItemGraph *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: baseRevid];
        COSQLiteStorePersistentRootBackingStore *backing2 = [self backingStoreForRevisionID: finalRevid];
        NSParameterAssert(backing == backing2);
        
        result = [backing partialItemGraphFromRevid: [backing revidForRevisionID: baseRevid]
                                            toRevid: [backing revidForRevisionID: finalRevid]];
    });
    
    return result;
}

- (COItemGraph *) itemGraphForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    
    __block COItemGraph *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
        result = [backing itemGraphForRevid: [backing revidForRevisionID: aToken]];
    });
    return result;
}

- (ETUUID *) rootObjectUUIDForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    
    __block ETUUID *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
        result = [backing rootUUIDForRevid: [backing revidForRevisionID: aToken]];
    });
    
    return result;
}

- (COItem *) item: (ETUUID *)anitem atRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);

    __block COItem *item = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
        COItemGraph *tree = [backing itemGraphForRevid: [backing revidForRevisionID: aToken]
                                   restrictToItemUUIDs: S(anitem)];
        item = [tree itemForUUID: anitem];
    });
    return item;
}

/** @taskunit writing states */

/**
 * Updates SQL indexes so given a search query containing contents of
 * the items mentioned by modifiedItems, we can get back aRevision.
 *
 * We'll then have to search to see which persistent roots
 * and which branches reference that revision ID, but that should be really fast.
 */
- (void) updateSearchIndexesForItemTree: (id<COItemGraph>)anItemTree
                 revisionIDBeingWritten: (CORevisionID *)aRevision
{
    assert(dispatch_get_current_queue() == queue_);
    
    [db_ savepoint: @"updateSearchIndexesForItemUUIDs"];
    
    
    ETUUID *backingStoreUUID = [self backingUUIDForPersistentRootUUID: [aRevision revisionPersistentRootUUID]];
    NSData *backingUUIDData = [backingStoreUUID dataValue];
    
    NSMutableArray *ftsContent = [NSMutableArray array];
    for (ETUUID *uuid in [anItemTree itemUUIDs])
    {
        COItem *itemToIndex = [anItemTree itemForUUID: uuid];
        NSString *itemFtsContent = [itemToIndex fullTextSearchContent];
        [ftsContent addObject: itemFtsContent];

        // Look for references to other persistent roots.
        for (ETUUID *referenced in [itemToIndex allReferencedPersistentRootUUIDs])
        {
            [db_ executeUpdate: @"INSERT INTO proot_refs(root_id, revid, embedded_object_uuid, dest_root_id) VALUES(?,?,?,?)",
                backingUUIDData,
                [[aRevision revisionUUID] dataValue],
                [uuid dataValue],
                [referenced dataValue]];
        }
        
        // Look for attachments
        for (NSData *attachment in [itemToIndex attachments])
        {
            [db_ executeUpdate: @"INSERT INTO attachment_refs(root_id, revid, attachment_hash) VALUES(?,?,?)",
             backingUUIDData ,
             [[aRevision revisionUUID] dataValue],
             attachment];
        }
    }
    NSString *allItemsFtsContent = [ftsContent componentsJoinedByString: @" "];    
    
    [db_ executeUpdate: @"INSERT INTO fts_docid_to_revisionid(backingstore, revid) VALUES(?, ?)",
     backingUUIDData,
     [[aRevision revisionUUID] dataValue]];
    
    [db_ executeUpdate: @"INSERT INTO fts(docid, text) VALUES(?,?)",
     [NSNumber numberWithLongLong: [db_ lastInsertRowId]],
     allItemsFtsContent];
    
    [db_ releaseSavepoint: @"updateSearchIndexesForItemUUIDs"];
    
    //NSLog(@"Index text '%@' at revision id %@", allItemsFtsContent, aRevision);
    
    assert(![db_ hadError]);
}

- (NSArray *) revisionIDsMatchingQuery: (NSString *)aQuery
{
    NSMutableArray *result = [NSMutableArray array];
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, revid FROM "
                           "(SELECT backingstore, revid FROM fts_docid_to_revisionid WHERE docid IN (SELECT docid FROM fts WHERE text MATCH ?)) "
                           "INNER JOIN persistentroots USING(backingstore)", aQuery];

        while ([rs next])
        {
            CORevisionID *revId = [CORevisionID revisionWithPersistentRootUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]
                                                               revisionUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]]];
            [result addObject: revId];
        }
        [rs close];
    });
    
    return result;
}

// Actual implementation used by action
- (BOOL) writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                           revisionUUID: (ETUUID *)aRevisionUUID
                               metadata: (NSDictionary *)metadata
                       parentRevisionID: (ETUUID *)aParent
                  mergeParentRevisionID: (ETUUID *)aMergeParent
                     persistentRootUUID: (ETUUID *)aUUID
                             branchUUID: (ETUUID*)branch
{
    assert(dispatch_get_current_queue() == queue_);
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aUUID];
    if (backing == nil)
    {
        return NO;
    }
    
    CORevisionID *revid = [backing writeItemGraph: anItemTree
                                     revisionUUID: aRevisionUUID
                                     withMetadata: metadata
                                       withParent: [backing revidForUUID: aParent]
                                  withMergeParent: [backing revidForUUID: aMergeParent]
	                                   branchUUID: branch
                               persistentrootUUID: aUUID
                                            error: NULL];
    
    if (revid == nil)
    {
        NSLog(@"Error creating revision");
    }
    
    if (revid != nil)
    {
        assert([backing hasRevid: [backing revidForUUID: [revid revisionUUID]]]);
        
        [self updateSearchIndexesForItemTree: anItemTree
                      revisionIDBeingWritten: revid];
        return YES;
    }
    else
    {
        return NO;
    }
}

// Public method
- (CORevisionID *) writeRevisionWithItemGraph: (COItemGraph*)anItemTree
                                 revisionUUID: (ETUUID *)aRevisionUUID
                                     metadata: (NSDictionary *)metadata
                             parentRevisionID: (CORevisionID *)aParent
                        mergeParentRevisionID: (CORevisionID *)aMergeParent
                                   branchUUID: (ETUUID *)aBranchUUID
                           persistentRootUUID: (ETUUID *)aPersistentRootUUID
                                        error: (NSError **)error
{
    [transaction_ writeRevisionWithModifiedItems: anItemTree
                                    revisionUUID: aRevisionUUID
                                        metadata: metadata
                                parentRevisionID: aParent.revisionUUID
                           mergeParentRevisionID: aMergeParent.revisionUUID
                              persistentRootUUID: aPersistentRootUUID
                                      branchUUID: aBranchUUID];
    
    return [CORevisionID revisionWithPersistentRootUUID: aPersistentRootUUID
                                           revisionUUID: aRevisionUUID];
}

/** @taskunit persistent roots */

- (BOOL) checkAndUpdateChangeCount: (int64_t *)aChangeCount forPersistentRootId: (NSNumber *)root_id
{
    return YES;
//    
//    const int64_t user = *aChangeCount;
//    const int64_t actual = [db_ int64ForQuery: @"SELECT changecount FROM persistentroots WHERE root_id = ?", root_id];
//    
//    if (actual == user)
//    {
//        const int64_t newCount = user + 1;
//        
//        [db_ executeUpdate: @"UPDATE persistentroots SET changecount = ? WHERE root_id = ?",
//         [NSNumber numberWithLongLong: newCount],
//         root_id];
//        
//        *aChangeCount = newCount;
//        return YES;
//    }
//    return NO;
}

- (NSArray *) persistentRootUUIDs
{
    NSMutableArray *result = [NSMutableArray array];
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT uuid FROM persistentroots WHERE deleted = 0"];
        while ([rs next])
        {
            [result addObject: [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]];
        }
        [rs close];
    });
    return result;
}

- (NSArray *) deletedPersistentRootUUIDs
{
    NSMutableArray *result = [NSMutableArray array];
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT uuid FROM persistentroots WHERE deleted = 1"];
        while ([rs next])
        {
            [result addObject: [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]];
        }
        [rs close];
    });
    return result;
}

- (COPersistentRootInfo *) persistentRootInfoForUUID: (ETUUID *)aUUID
{
    if (aUUID == nil)
    {
        return nil;
    }
    
    __block COPersistentRootInfo *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        
        ETUUID *currBranch = nil;
        ETUUID *backingUUID = nil;
        BOOL deleted = NO;
        NSMutableDictionary *branchDict = [NSMutableDictionary dictionary];

        
        [db_ savepoint: @"persistentRootInfoForUUID"]; // N.B. The transaction is so the two SELECTs see the same DB. Needed?

        {
            FMResultSet *rs = [db_ executeQuery: @"SELECT currentbranch, backingstore, deleted FROM persistentroots WHERE uuid = ?", [aUUID dataValue]];
            if ([rs next])
            {
                currBranch = [rs dataForColumnIndex: 0] != nil
                    ? [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]
                    : nil;
                backingUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
                deleted = [rs boolForColumnIndex: 2];
            }
            else
            {
                [rs close];
                [db_ releaseSavepoint: @"persistentRootInfoForUUID"];
                
                return;
            }
            [rs close];
        }
        
        {
            FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, initial_revid, current_revid, metadata, deleted FROM branches WHERE proot = ?", [aUUID dataValue]];
            while ([rs next])
            {
                ETUUID *branch = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
                CORevisionID *initialRevid = [CORevisionID revisionWithPersistentRootUUID: backingUUID
                                                                       revisionUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]]];
                CORevisionID *currentRevid = [CORevisionID revisionWithPersistentRootUUID: backingUUID
                                                                          revisionUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]]];
                id branchMeta = [self readMetadata: [rs dataForColumnIndex: 3]];
                
                COBranchInfo *state = [[COBranchInfo alloc] init];
                state.UUID = branch;
                state.initialRevisionID = initialRevid;
                state.currentRevisionID = currentRevid;
                state.metadata = branchMeta;
                state.deleted = [rs boolForColumnIndex: 4];
                
                [branchDict setObject: state forKey: branch];
            }
            [rs close];
        }
        
        [db_ releaseSavepoint: @"persistentRootInfoForUUID"];
        
        result = [[COPersistentRootInfo alloc] init];
        result.UUID = aUUID;
        result.branchForUUID = branchDict;
        result.currentBranchUUID = currBranch;
        result.deleted = deleted;
    });
    
    return result;
}

- (ETUUID *)persistentRootUUIDForBranchUUID: (ETUUID *)aBranchUUID
{
	NILARG_EXCEPTION_TEST(aBranchUUID);

	__block ETUUID *prootUUID = nil;
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT proot FROM branches WHERE uuid = ?",
            [aBranchUUID dataValue]];


        if ([rs next])
        {
            prootUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            ETAssert([rs next] == NO);
        }

        [rs close];
    });
    
	return prootUUID;
}

/** @taskunit writing persistent roots */

- (NSData *) writeMetadata: (NSDictionary *)meta
{
    NSData *data = nil;
    if (meta != nil)
    {
        data = [NSJSONSerialization dataWithJSONObject: meta options: 0 error: NULL];
    }
    return data;
}

- (NSDictionary *) readMetadata: (NSData*)data
{
    if (data != nil)
    {
        return [NSJSONSerialization JSONObjectWithData: data
                                               options: 0
                                                 error: NULL];
    }
    return nil;
}

- (COPersistentRootInfo *) createPersistentRootWithUUID: (ETUUID *)uuid
                                             branchUUID: (ETUUID *)aBranchUUID
                                                 isCopy: (BOOL)isCopy
                                        initialRevision: (CORevisionID *)aRevision
                                                  error: (NSError **)error
{    
    [transaction_ createPersistentRootWithUUID: uuid
                         persistentRootForCopy: isCopy ? aRevision.revisionPersistentRootUUID : nil];
    
    [transaction_ createBranchWithUUID: aBranchUUID
                       initialRevision: aRevision.revisionUUID
                     forPersistentRoot: uuid];
    
    [transaction_ setCurrentBranch: aBranchUUID
                 forPersistentRoot: uuid];
                                      
    COPersistentRootInfo *plist = [[COPersistentRootInfo alloc] init];
    plist.UUID = uuid;
    plist.deleted = NO;
    
    if (aBranchUUID != nil)
    {
        COBranchInfo *branch = [[COBranchInfo alloc] init];
        branch.UUID = aBranchUUID;
        branch.initialRevisionID = aRevision;
        branch.currentRevisionID = aRevision;
        branch.metadata = nil;
        branch.deleted = NO;
        
        plist.currentBranchUUID = aBranchUUID;
        plist.branchForUUID = @{aBranchUUID : branch};
    }
    
    return plist;
}

- (COPersistentRootInfo *) createPersistentRootWithInitialItemGraph: (id<COItemGraph>)contents
                                                               UUID: (ETUUID *)persistentRootUUID
                                                         branchUUID: (ETUUID *)aBranchUUID
                                                   revisionMetadata: (NSDictionary *)metadata
                                                              error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: persistentRootUUID];
    
    NILARG_EXCEPTION_TEST(contents);
    NILARG_EXCEPTION_TEST(persistentRootUUID);
    NILARG_EXCEPTION_TEST(aBranchUUID);
    
    CORevisionID *revId = [self writeRevisionWithItemGraph: contents
                                                  revisionUUID: [ETUUID UUID]
                                                      metadata: metadata
                                              parentRevisionID: nil
                                         mergeParentRevisionID: nil
                                                branchUUID: aBranchUUID
                                            persistentRootUUID: persistentRootUUID
                                                     error: error];
    
    if (revId == nil)
    {
        return nil;
    }
    
    return [self createPersistentRootWithUUID: persistentRootUUID
                                   branchUUID: aBranchUUID
                                       isCopy: NO
                              initialRevision: revId
                                        error: error];
}

- (COPersistentRootInfo *) createPersistentRootWithInitialRevision: (CORevisionID *)aRevision
                                                              UUID: (ETUUID *)persistentRootUUID
                                                        branchUUID: (ETUUID *)aBranchUUID
                                                             error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: persistentRootUUID];
    
    NILARG_EXCEPTION_TEST(aRevision);
    NILARG_EXCEPTION_TEST(persistentRootUUID);
    NILARG_EXCEPTION_TEST(aBranchUUID);
    //[self validateRevision: aRevision];
    
    return [self createPersistentRootWithUUID: persistentRootUUID
                                   branchUUID: aBranchUUID
                                       isCopy: YES
                              initialRevision: aRevision
                                        error: error];
}

- (COPersistentRootInfo *) createPersistentRootWithUUID: (ETUUID *)persistentRootUUID
                                                  error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: persistentRootUUID];
    
    [transaction_ createPersistentRootWithUUID: persistentRootUUID
                         persistentRootForCopy: nil];
    
    COPersistentRootInfo *plist = [[COPersistentRootInfo alloc] init];
    plist.UUID = persistentRootUUID;
    plist.deleted = NO;
    
    return plist;
}

- (BOOL) deletePersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ deletePersistentRoot: aRoot];
    
    return YES;
}

- (BOOL) undeletePersistentRoot: (ETUUID *)aRoot
                          error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ undeletePersistentRoot: aRoot];
    
    return YES;
}

- (BOOL) setCurrentBranch: (ETUUID *)aBranch
		forPersistentRoot: (ETUUID *)aRoot
                 error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ setCurrentBranch: aBranch
                 forPersistentRoot: aRoot];
    
    return YES;
}

- (BOOL) createBranchWithUUID: (ETUUID *)branchUUID
                 parentBranch: (ETUUID *)aParentBranch
              initialRevision: (CORevisionID *)revId
            forPersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ createBranchWithUUID: branchUUID
                       initialRevision: revId.revisionUUID
                     forPersistentRoot: aRoot];
    
    return YES;
}

- (void) validateRevision: (CORevisionID*)aRev
{
    if (aRev == nil)
    {
        return;
    }
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: [aRev revisionPersistentRootUUID]];
    
    if (![backing hasRevid: [backing revidForRevisionID: aRev]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"CORevisionID %@ has an index not present in the backing store", aRev];
    }
}

- (void) validateRevision: (CORevisionID*)aRev
        forPersistentRoot: (ETUUID *)aRoot
{
    if (aRev == nil)
    {
        return;
    }
    
    [self validateRevision: aRev];
}

- (BOOL) setCurrentRevision: (CORevisionID*)currentRev
               initialRevision: (CORevisionID*)initialRev
                  forBranch: (ETUUID *)aBranch
           ofPersistentRoot: (ETUUID *)aRoot
                      error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ setCurrentRevision: currentRev.revisionUUID
                           forBranch: aBranch
                    ofPersistentRoot: aRoot];
    
    return YES;
}


- (BOOL) deleteBranch: (ETUUID *)aBranch
     ofPersistentRoot: (ETUUID *)aRoot
                error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ deleteBranch: aBranch
              ofPersistentRoot: aRoot];
    
    return YES;
}

- (BOOL) undeleteBranch: (ETUUID *)aBranch
       ofPersistentRoot: (ETUUID *)aRoot
                  error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ undeleteBranch: aBranch
                ofPersistentRoot: aRoot];
    
    return YES;
}

- (BOOL) setMetadata: (NSDictionary *)meta
           forBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot
               error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    [transaction_ setMetadata: meta
                    forBranch: aBranch
             ofPersistentRoot: aRoot];
    
    return YES;
}

- (BOOL) finalizeGarbageAttachments
{
    assert(dispatch_get_current_queue() == queue_);
    
    NSMutableSet *garbage = [NSMutableSet setWithArray: [self attachments]];
    
    FMResultSet *rs = [db_ executeQuery: @"SELECT attachment_hash FROM attachment_refs"];
    while ([rs next])
    {
        [garbage removeObject: [rs dataForColumnIndex: 0]];
    }
    [rs close];

    for (NSData *hash in garbage)
    {
        if (![self deleteAttachment: hash])
        {
            return NO;
        }
    }
    return YES;
}

// Must not be wrapped in a transaction
- (BOOL) finalizeDeletionsForPersistentRoot: (ETUUID *)aRoot
                                      error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        
        ETUUID *backingUUID = [self backingUUIDForPersistentRootUUID: aRoot];
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: backingUUID error: NULL];
        //NSNumber *backingId = [self rootIdForPersistentRootUUID: backingUUID];
        NSData *backingUUIDData = [backingUUID dataValue];
        
        [db_ beginTransaction];
        
        // Delete branches / the persistent root
        
        [db_ executeUpdate: @"DELETE FROM branches WHERE proot IN (SELECT uuid FROM persistentroots WHERE deleted = 1 AND backingstore = ?)", backingUUIDData];
        [db_ executeUpdate: @"DELETE FROM branches WHERE deleted = 1 AND proot IN (SELECT uuid FROM persistentroots WHERE backingstore = ?)", backingUUIDData];
        [db_ executeUpdate: @"DELETE FROM persistentroots WHERE deleted = 1 AND backingstore = ?", backingUUIDData];
        
        NSMutableIndexSet *keptRevisions = [NSMutableIndexSet indexSet];
        
        FMResultSet *rs = [db_ executeQuery: @"SELECT "
                                                "branches.current_revid, "
                                                "branches.initial_revid "
                                                "FROM persistentroots "
                                                "INNER JOIN branches ON persistentroots.uuid = branches.proot "
                                                "WHERE persistentroots.backingstore = ?", backingUUIDData];
        while ([rs next])
        {
            ETUUID *head = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            ETUUID *initial = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
            
            NSIndexSet *revs = [backing revidsFromRevid: [backing revidForUUID: initial]
                                                toRevid: [backing revidForUUID: head]];
            [keptRevisions addIndexes: revs];
        }
        [rs close];
        
        // Now for each index set in deletedRevisionsForBackingStore, subtract the index set
        // in keptRevisionsForBackingStore
        
        NSMutableIndexSet *deletedRevisions = [NSMutableIndexSet indexSet];
        [deletedRevisions addIndexes: [backing revidsUsedRange]];
        [deletedRevisions removeIndexes: keptRevisions];
        
    //    for (NSUInteger i = [deletedRevisions firstIndex]; i != NSNotFound; i = [deletedRevisions indexGreaterThanIndex: i])
    //    {
    //        
    //        [db_ executeUpdate: @"DELETE FROM attachment_refs WHERE root_id = ? AND revid = ?",
    //         [backingUUID dataValue],
    //         [NSNumber numberWithLongLong: i]];
    //        
    //        // FIXME: FTS, proot_refs
    //    }
        
        assert([db_ commit]);
        
        // Delete the actual revisions
        assert([backing deleteRevids: deletedRevisions]);

        [self finalizeGarbageAttachments];
    });
    
    return YES;
}

/**
 * @returns an array of COSearchResult
 */
- (NSArray *) referencesToPersistentRoot: (ETUUID *)aUUID
{
    NSMutableArray *results = [NSMutableArray array];
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT root_id, revid, embedded_object_uuid FROM proot_refs WHERE dest_root_id = ?", [aUUID dataValue]];
        while ([rs next])
        {
            ETUUID *root = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            ETUUID *revUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
            ETUUID *embedded_object_uuid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
            
            COSearchResult *searchResult = [[COSearchResult alloc] init];
            searchResult.embeddedObjectUUID = embedded_object_uuid;
            searchResult.revision = [CORevisionID revisionWithPersistentRootUUID: root
                                                                 revisionUUID: revUUID];
            [results addObject: searchResult];
        }
        [rs close];
    });
    
    return results;
}

- (void) postCommitNotificationsForTransaction: (ETUUID *)aTransaction
{
    for (ETUUID *persistentRoot in modifiedPersistentRootsUUIDs_)
    {
        NSDictionary *userInfo = @{kCOPersistentRootUUID : [persistentRoot stringValue],
                                   kCOPersistentRootTransactionUUID : [aTransaction stringValue],
                                   kCOStoreUUID : [[self UUID] stringValue],
                                   kCOStoreURL : [[self URL] absoluteString]};
                
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[NSNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
                                                                object: self
                                                              userInfo: userInfo];

            
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
                                                                           object: [[self UUID] stringValue]
                                                                         userInfo: userInfo
                                                               deliverImmediately: NO];
        });
    }
}

- (FMDatabase *) database
{
    assert(dispatch_get_current_queue() == queue_);
    return db_;
}

- (NSString *) description
{
    NSMutableString *result = [NSMutableString string];
    [result appendFormat: @"<COSQLiteStore at %@ (UUID: %@)\n", self.URL, self.UUID];
    for (ETUUID *backingUUID in [self allBackingUUIDs])
    {
        [result appendFormat: @"\t backing UUID %@ (containing ", backingUUID];
        
        for (ETUUID *persistentRoot in  [[NSSet setWithArray: [self persistentRootUUIDs]]
                                         objectsPassingTest: ^(id obj, BOOL *stop) {
                                             return [[self backingUUIDForPersistentRootUUID: obj] isEqual: backingUUID];
                                         }])
        {
            [result appendFormat: @"%@ ", persistentRoot];
        }
        
        [result appendFormat: @")\n"];
        
        COSQLiteStorePersistentRootBackingStore *bs = [self backingStoreForUUID: backingUUID error: NULL];
        for (int64_t i=0 ;; i++)
        {
            CORevisionID *revisionID = [bs revisionIDForRevid: i];
            if (revisionID == nil)
            {
                break;
            }
            [result appendFormat: @"\t\t %lld (UUID: %@)\n", (long long int)i, [revisionID revisionUUID]];
        }
    }
    return result;
}

- (void) clearStore
{
    dispatch_sync(queue_, ^() {
        [db_ beginDeferredTransaction];
        
        [db_ executeUpdate: @"DELETE FROM persistentroots"];
        
        [db_ executeUpdate: @"DELETE FROM branches"];
        
        [db_ executeUpdate: @"DELETE FROM proot_refs"];
        [db_ executeUpdate: @"DELETE FROM attachment_refs"];
                
        [db_ executeUpdate: @"DELETE FROM fts_docid_to_revisionid"];
        [db_ executeUpdate: @"DELETE FROM fts"];
        [db_ commit];
    });
}

@end

NSString *COStorePersistentRootDidChangeNotification = @"COStorePersistentRootDidChangeNotification";
NSString *kCOPersistentRootUUID = @"COPersistentRootUUID";
NSString *kCOPersistentRootTransactionUUID = @"COPersistentRootTransactionUUID";
NSString *kCOStoreUUID = @"COStoreUUID";
NSString *kCOStoreURL = @"COStoreURL";
