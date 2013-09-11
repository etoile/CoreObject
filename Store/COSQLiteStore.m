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

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface COSQLiteStore (AttachmentsPrivate)

- (NSArray *) attachments;
- (BOOL) deleteAttachment: (NSData *)hash;

@end

@implementation COSQLiteStore

- (id)initWithURL: (NSURL*)aURL
{
	SUPERINIT;
    
	url_ = [aURL retain];
	backingStores_ = [[NSMutableDictionary alloc] init];
    backingStoreUUIDForPersistentRootUUID_ = [[NSMutableDictionary alloc] init];
    modifiedPersistentRootsUUIDs_ = [[NSMutableSet alloc] init];
    
    // Ignore if this fails (it will fail if the directory already exists.)
    // If it really fails, we will notice later when we try to open the sqlite db
	[[NSFileManager defaultManager] createDirectoryAtPath: [url_ path]
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: NULL];
	
    db_ = [[FMDatabase alloc] initWithPath: [[url_ path] stringByAppendingPathComponent: @"index.sqlite"]];
    
    [db_ setShouldCacheStatements: YES];
	[db_ setCrashOnErrors: YES];
    [db_ setLogsErrors: YES];
    
	if (![db_ open])
	{
        [self release];
		return nil;
	}
    
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
        ASSIGN(_uuid, [ETUUID UUID]);
        [db_ executeUpdate: @"CREATE TABLE storeMetadata(version INTEGER, uuid BLOB)"];
        [db_ executeUpdate: @"INSERT INTO storeMetadata VALUES(1, ?)", [_uuid dataValue]];
    }
    else
    {
        int version = [db_ intForQuery: @"SELECT version FROM storeMetadata"];
        if (1 != version)
        {
            NSLog(@"Error, store version %d, only version 1 is supported", version);
            [self release];
            return nil;
        }
        
        ASSIGN(_uuid, [ETUUID UUIDWithData: [db_ dataForQuery: @"SELECT uuid FROM storeMetadata"]]);
    }
    
    // Persistent Root and Branch tables
    
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS persistentroots ("
     "uuid BLOB PRIMARY KEY NOT NULL, backingstore BLOB NOT NULL, "
     "currentbranch BLOB, deleted BOOLEAN DEFAULT 0, transactionuuid BLOB)"];
    
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS branches (uuid BLOB NOT NULL, "
     "proot BLOB NOT NULL, tail_revid BLOB NOT NULL, current_revid BLOB NOT NULL, "
     "metadata BLOB, deleted BOOLEAN DEFAULT 0, "
     "PRIMARY KEY (uuid, proot))"];

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
        [self release];
		return nil;
	}

    
	return self;
}

- (void)dealloc
{
    [db_ release];
	[url_ release];
    [backingStores_ release];
    [backingStoreUUIDForPersistentRootUUID_ release];
    [modifiedPersistentRootsUUIDs_ release];
    [_uuid release];
	[super dealloc];
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
    return [db_ beginTransaction];
}

- (BOOL) commitTransactionWithError: (NSError **)error
{
    return [self commitTransactionWithUUID: [ETUUID UUID] withError: error];
}

- (BOOL) commitTransactionWithUUID: (ETUUID *)transactionUUID withError: (NSError **)error
{
    // update the last transaction field before we commit.

    for (ETUUID *modifiedUUID in modifiedPersistentRootsUUIDs_)
    {
        [db_ executeUpdate: @"UPDATE persistentroots SET transactionuuid = ? WHERE uuid = ?", [transactionUUID dataValue], [modifiedUUID dataValue]];
    }

    BOOL ok = [db_ commit];

    if (ok)
    {
        [self postCommitNotificationsForTransaction: transactionUUID];
    }
    return ok;
}

- (void) recordModifiedPersistentRoot: (ETUUID *)persistentRootUUID
{
    [modifiedPersistentRootsUUIDs_ addObject: persistentRootUUID];
}

- (void) checkInTransaction
{
    assert([db_ inTransaction]);
}

- (NSArray *) allBackingUUIDs
{
    NSMutableArray *result = [NSMutableArray array];
    FMResultSet *rs = [db_ executeQuery: @"SELECT DISTINCT backingstore FROM persistentroots"];
    sqlite3_stmt *statement = [[rs statement] statement];
    
    while ([rs next])
    {
        const void *data = sqlite3_column_blob(statement, 0);
        const int dataSize = sqlite3_column_bytes(statement, 0);
      
        assert(dataSize == 16);
        
        ETUUID *uuid = [[ETUUID alloc] initWithUUID: data];
        [result addObject: uuid];
        [uuid release];
    }
    [rs close];
    return result;
}

- (CORevisionID *) revisionIDForRevisionUUID: (ETUUID *)aRevisionUUID
                          persistentRootUUID: (ETUUID *)aPersistentRoot
{
    ETUUID *backingUUID = [self backingUUIDForPersistentRootUUID: aPersistentRoot];
    
    return [CORevisionID revisionWithBackinStoreUUID: backingUUID
                                        revisionUUID: aRevisionUUID];
}

- (ETUUID *) backingUUIDForPersistentRootUUID: (ETUUID *)aUUID
{
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
            [NSException raise: NSInvalidArgumentException format: @"persistent root %@ not found", aUUID];
        }        
        [backingStoreUUIDForPersistentRootUUID_ setObject: backingUUID forKey: aUUID];
    }
    return backingUUID;
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForPersistentRootUUID: (ETUUID *)aUUID
{
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
        [result release];
    }
    return result;
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForRevisionID: (CORevisionID *)aToken
{
    return [self backingStoreForUUID: [aToken backingStoreUUID] error: NULL];
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
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    return [backing revisionForID: aToken];
}

- (COItemGraph *) partialItemGraphFromRevisionID: (CORevisionID *)baseRevid
                                    toRevisionID: (CORevisionID *)finalRevid
{
    NSParameterAssert(baseRevid != nil);
    NSParameterAssert(finalRevid != nil);
    NSParameterAssert([[baseRevid backingStoreUUID] isEqual: [finalRevid backingStoreUUID]]);
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: baseRevid];
    COItemGraph *result = [backing partialItemGraphFromRevid: [backing revidForRevisionID: baseRevid]
                                                     toRevid: [backing revidForRevisionID: finalRevid]];
    return result;
}

- (COItemGraph *) itemGraphForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    COItemGraph *result = [backing itemGraphForRevid: [backing revidForRevisionID: aToken]];
    return result;
}

- (ETUUID *) rootObjectUUIDForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    return [backing rootUUIDForRevid: [backing revidForRevisionID: aToken]];
}

- (COItem *) item: (ETUUID *)anitem atRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    COItemGraph *tree = [backing itemGraphForRevid: [backing revidForRevisionID: aToken]
                               restrictToItemUUIDs: S(anitem)];
    COItem *item = [tree itemForUUID: anitem];
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
- (void) updateSearchIndexesForItemUUIDs: (NSArray *)modifiedItems
                              inItemTree: (id<COItemGraph>)anItemTree
                  revisionIDBeingWritten: (CORevisionID *)aRevision
{
    if (modifiedItems == nil)
    {
        modifiedItems = [anItemTree itemUUIDs];
    }
    
    [db_ savepoint: @"updateSearchIndexesForItemUUIDs"];
    
    NSData *backingUUIDData = [[aRevision backingStoreUUID] dataValue];
    
    NSMutableArray *ftsContent = [NSMutableArray array];
    for (ETUUID *uuid in modifiedItems)
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
    FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, revid FROM "
                       "(SELECT backingstore, revid FROM fts_docid_to_revisionid WHERE docid IN (SELECT docid FROM fts WHERE text MATCH ?)) "
                       "INNER JOIN persistentroots USING(backingstore)", aQuery];

    while ([rs next])
    {
        CORevisionID *revId = [CORevisionID revisionWithBackinStoreUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]
                                                           revisionUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]]];
        [result addObject: revId];
    }
    [rs close];
    return result;
}

- (CORevisionID *) writeRevisionWithItemGraph: (id<COItemGraph>)anItemTree
                                     metadata: (NSDictionary *)metadata
                             parentRevisionID: (CORevisionID *)aParent
                        mergeParentRevisionID: (CORevisionID *)aMergeParent
                                modifiedItems: (NSArray*)modifiedItems // array of COUUID
                                        error: (NSError **)error
{
    [self checkInTransaction];
    [self validateRevision: aParent];
    
    NSParameterAssert(anItemTree != nil);
    NSParameterAssert(aParent != nil);
    
    return [self writeItemTree: anItemTree
                  revisionUUID: [ETUUID UUID]
                  withMetadata: metadata
          withParentRevisionID: aParent
         mergeParentRevisionID: aMergeParent
        inBackingStoreWithUUID: [aParent backingStoreUUID]
                 modifiedItems: modifiedItems
                         error: error];
}

- (CORevisionID *) writeRevisionWithItemGraph: (id<COItemGraph>)anItemTree
                                 revisionUUID: (ETUUID *)aRevisionUUID
                                     metadata: (NSDictionary *)metadata
                             parentRevisionID: (CORevisionID *)aParent
                        mergeParentRevisionID: (CORevisionID *)aMergeParent
                           persistentRootUUID: (ETUUID *)aUUID
                                modifiedItems: (NSArray*)modifiedItems // array of COUUID
                                        error: (NSError **)error
{
    [self checkInTransaction];
    [self validateRevision: aParent];
    
    NSParameterAssert(anItemTree != nil);
    
    return [self writeItemTree: anItemTree
                  revisionUUID: aRevisionUUID
                  withMetadata: metadata
          withParentRevisionID: aParent
         mergeParentRevisionID: aMergeParent
        inBackingStoreWithUUID: [self backingUUIDForPersistentRootUUID: aUUID]
                 modifiedItems: modifiedItems
                         error: error];
}

- (CORevisionID *) writeItemTreeWithNoParent: (id<COItemGraph>)anItemTree
                                withMetadata: (NSDictionary *)metadata
                      inBackingStoreWithUUID: (ETUUID *)aBacking
                                       error: (NSError **)error
{
    return [self writeItemTree: anItemTree
                  revisionUUID: [ETUUID UUID]
                  withMetadata: metadata
          withParentRevisionID: nil
         mergeParentRevisionID: nil
        inBackingStoreWithUUID: aBacking
                 modifiedItems: nil
                         error: error];
}


- (CORevisionID *) writeItemTree: (id<COItemGraph>)anItemTree
                    revisionUUID: (ETUUID *)aRevisionUUID
                    withMetadata: (NSDictionary *)metadata
            withParentRevisionID: (CORevisionID *)parentRevid
           mergeParentRevisionID: (CORevisionID *)aMergeParent
          inBackingStoreWithUUID: (ETUUID *)backingUUID
                   modifiedItems: (NSArray*)modifiedItems // array of COUUID
                           error: (NSError **)error
{
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: backingUUID
                                                                           error: error];
    if (backing == nil)
    {
        return nil;
    }
    
    CORevisionID *revid = [backing writeItemGraph: anItemTree
                                     revisionUUID: aRevisionUUID
                                     withMetadata: metadata
                                       withParent: [backing revidForRevisionID: parentRevid]
                                  withMergeParent: [backing revidForRevisionID: aMergeParent]
                                    modifiedItems: modifiedItems
                                            error: error];
    
    if (revid == nil)
    {
        NSLog(@"Error creating revision");
    }
    
    if (revid != nil)
    {
        assert([backing hasRevid: [backing revidForUUID: [revid revisionUUID]]]);
        
        [self updateSearchIndexesForItemUUIDs: modifiedItems
                                   inItemTree: anItemTree
                       revisionIDBeingWritten: revid];
    }
    
    return revid;
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
    // FIXME: Benchmark vs join
    FMResultSet *rs = [db_ executeQuery: @"SELECT uuid FROM persistentroots WHERE deleted = 0"];
    while ([rs next])
    {
        [result addObject: [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]];
    }
    [rs close];
    return result;
}

- (NSArray *) deletedPersistentRootUUIDs
{
    NSMutableArray *result = [NSMutableArray array];
    FMResultSet *rs = [db_ executeQuery: @"SELECT uuid FROM persistentroots WHERE deleted = 1"];
    while ([rs next])
    {
        [result addObject: [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]];
    }
    [rs close];
    return result;
}

- (COPersistentRootInfo *) persistentRootInfoForUUID: (ETUUID *)aUUID
{
    if (aUUID == nil)
    {
        return nil;
    }
    
    ETUUID *currBranch = nil;
    ETUUID *backingUUID = nil;
    BOOL deleted = NO;
    
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
            return nil;
        }
        [rs close];
    }
    
    NSMutableDictionary *branchDict = [NSMutableDictionary dictionary];
    
    {
        FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, tail_revid, current_revid, metadata, deleted FROM branches WHERE proot = ?", [aUUID dataValue]];
        while ([rs next])
        {
            ETUUID *branch = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            CORevisionID *tailRevid = [CORevisionID revisionWithBackinStoreUUID: backingUUID
                                                                   revisionUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]]];
            CORevisionID *currentRevid = [CORevisionID revisionWithBackinStoreUUID: backingUUID
                                                                      revisionUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]]];
            id branchMeta = [self readMetadata: [rs dataForColumnIndex: 3]];
            
            COBranchInfo *state = [[[COBranchInfo alloc] init] autorelease];
            state.UUID = branch;
            state.tailRevisionID = tailRevid;
            state.currentRevisionID = currentRevid;
            state.metadata = branchMeta;
            state.deleted = [rs boolForColumnIndex: 4];
            
            [branchDict setObject: state forKey: branch];
        }
        [rs close];
    }
    
    [db_ releaseSavepoint: @"persistentRootInfoForUUID"];

    COPersistentRootInfo *result = [[[COPersistentRootInfo alloc] init] autorelease];
    result.UUID = aUUID;
    result.branchForUUID = branchDict;
    result.currentBranchUUID = currBranch;
    result.deleted = deleted;
    
    return result;
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
                                        initialRevision: (CORevisionID *)revId
                                                  error: (NSError **)error
{    
    [db_ savepoint: @"createPersistentRootWithUUID"];
    
    [db_ executeUpdate: @"INSERT INTO persistentroots (uuid, "
           "backingstore, currentbranch, deleted) VALUES(?,?,NULL,0)",
           [uuid dataValue],
           [[revId backingStoreUUID] dataValue]];

    if (aBranchUUID != nil)
    {    
        [db_ executeUpdate: @"INSERT INTO branches (uuid, proot, tail_revid, current_revid, metadata, deleted) VALUES(?,?,?,?,NULL,0)",
               [aBranchUUID dataValue],
               [uuid dataValue],
               [[revId revisionUUID] dataValue],
               [[revId revisionUUID] dataValue]];
        
        
        [db_ executeUpdate: @"UPDATE persistentroots SET currentbranch = ? WHERE uuid = ?",
          [aBranchUUID dataValue],
          [uuid dataValue]];
    }
    
    [db_ releaseSavepoint: @"createPersistentRootWithUUID"];
    
    // Return info
    

                                  
    COPersistentRootInfo *plist = [[[COPersistentRootInfo alloc] init] autorelease];
    plist.UUID = uuid;
    plist.deleted = NO;
    
    if (aBranchUUID != nil)
    {
        COBranchInfo *branch = [[[COBranchInfo alloc] init] autorelease];
        branch.UUID = aBranchUUID;
        branch.tailRevisionID = revId;
        branch.currentRevisionID = revId;
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
    
    CORevisionID *revId = [self writeItemTreeWithNoParent: contents
                                             withMetadata: metadata
                                   inBackingStoreWithUUID: persistentRootUUID
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
    [self validateRevision: aRevision];
    
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
    
    [db_ executeUpdate: @"INSERT INTO persistentroots (uuid, "
     "backingstore, currentbranch, deleted) VALUES(?,?,NULL,0)",
     [persistentRootUUID dataValue],
     [persistentRootUUID dataValue]];
    
    COPersistentRootInfo *plist = [[[COPersistentRootInfo alloc] init] autorelease];
    plist.UUID = persistentRootUUID;
    plist.deleted = NO;
    
    return plist;
}

- (BOOL) deletePersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = [db_ executeUpdate: @"UPDATE persistentroots SET deleted = 1 WHERE uuid = ?",
               [aRoot dataValue]];
    
    return ok;
}

- (BOOL) undeletePersistentRoot: (ETUUID *)aRoot
                          error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = [db_ executeUpdate: @"UPDATE persistentroots SET deleted = 0 WHERE uuid = ?",
               [aRoot dataValue]];
    
    return ok;
}

- (BOOL) setCurrentBranch: (ETUUID *)aBranch
		forPersistentRoot: (ETUUID *)aRoot
                 error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = [db_ executeUpdate: @"UPDATE persistentroots SET currentbranch = ? WHERE uuid = ? AND 0 = (SELECT deleted FROM branches WHERE uuid = ? AND proot = ?)",
               [aBranch dataValue], [aRoot dataValue],
               [aBranch dataValue], [aRoot dataValue]];

    ok = ok && ([db_ changes] > 0);
    
    return ok;
}

- (BOOL) createBranchWithUUID: (ETUUID *)branchUUID
              initialRevision: (CORevisionID *)revId
            forPersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NILARG_EXCEPTION_TEST(branchUUID);
    NILARG_EXCEPTION_TEST(revId);
    NILARG_EXCEPTION_TEST(aRoot);
    [self validateRevision: revId forPersistentRoot: aRoot];
    
    BOOL ok = [db_ executeUpdate: @"INSERT INTO branches (uuid, proot, tail_revid, current_revid, metadata, deleted) VALUES(?,?,?,?,NULL,0)",
     [branchUUID dataValue],
     [aRoot dataValue],
     [[revId revisionUUID] dataValue],
     [[revId revisionUUID] dataValue]];    
  
    if (!ok)
    {
        branchUUID = nil;
    }

    return ok;
}

- (void) validateRevision: (CORevisionID*)aRev
{
    if (aRev == nil)
    {
        return;
    }
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: [aRev backingStoreUUID] error: NULL];
    
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
    
    ETUUID *backingUUID = [self backingUUIDForPersistentRootUUID: aRoot];
    
    if (![[aRev backingStoreUUID] isEqual: backingUUID])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"CORevisionID %@ can not be used with persistent "
         @"root %@ (backing store %@) because the backing "
         @"stores do not match", aRev, aRoot, backingUUID];
    }
    
    [self validateRevision: aRev];
}

- (BOOL) setCurrentRevision: (CORevisionID*)currentRev
               tailRevision: (CORevisionID*)tailRev
                  forBranch: (ETUUID *)aBranch
           ofPersistentRoot: (ETUUID *)aRoot
                      error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    [self validateRevision: currentRev forPersistentRoot: aRoot];
    [self validateRevision: tailRev forPersistentRoot: aRoot];
    
    [db_ savepoint: @"setCurrentRevision"];
    
    NSData *branchData = [aBranch dataValue];
    NSData *prootData = [aRoot dataValue];
    
    if (currentRev != nil)
    {
        [db_ executeUpdate: @"UPDATE branches SET current_revid = ? WHERE uuid = ? AND proot = ?",
                [[currentRev revisionUUID] dataValue],
                branchData,
                prootData];
    }
    if (tailRev != nil)
    {
        [db_ executeUpdate: @"UPDATE branches SET tail_revid = ? WHERE uuid = ? AND proot = ?",
                [[tailRev revisionUUID] dataValue],
                branchData,
                prootData];
    }

    BOOL ok = [db_ releaseSavepoint: @"setCurrentRevision"];
    
    assert(ok);
    
    return ok;
}


- (BOOL) deleteBranch: (ETUUID *)aBranch
     ofPersistentRoot: (ETUUID *)aRoot
                error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = [db_ executeUpdate: @"UPDATE branches SET deleted = 1 WHERE uuid = ? AND proot = ? AND uuid != (SELECT currentbranch FROM persistentroots WHERE persistentroots.uuid = proot)",
               [aBranch dataValue],
               [aRoot dataValue]];
    if (ok)
    {
        ok = [db_ changes] > 0;
    }

    return ok;
}

- (BOOL) undeleteBranch: (ETUUID *)aBranch
       ofPersistentRoot: (ETUUID *)aRoot
                  error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = [db_ executeUpdate: @"UPDATE branches SET deleted = 0 WHERE uuid = ?",
               [aBranch dataValue]];
    
    return ok;
}

- (BOOL) setMetadata: (NSDictionary *)meta
           forBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot
               error: (NSError **)error
{
    [self checkInTransaction];
    [self recordModifiedPersistentRoot: aRoot];
    
    NSData *data = [self writeMetadata: meta];    
    BOOL ok = [db_ executeUpdate: @"UPDATE branches SET metadata = ? WHERE uuid = ?",
               data,
               [aBranch dataValue]];

    return ok;
}

- (BOOL) finalizeGarbageAttachments
{
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
                                            "branches.tail_revid "
                                            "FROM persistentroots "
                                            "INNER JOIN branches ON persistentroots.uuid = branches.proot "
                                            "WHERE persistentroots.backingstore = ?", backingUUIDData];
    while ([rs next])
    {
        ETUUID *head = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
        ETUUID *tail = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
        
        NSIndexSet *revs = [backing revidsFromRevid: [backing revidForUUID: tail]
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
    
    if (![db_ commit])
    {
        return NO;
    }
    
    // Delete the actual revisions
    if (![backing deleteRevids: deletedRevisions])
    {
        return NO;
    }

    [self finalizeGarbageAttachments];
    
    return YES;
}

/**
 * @returns an array of COSearchResult
 */
- (NSArray *) referencesToPersistentRoot: (ETUUID *)aUUID
{
    NSMutableArray *results = [NSMutableArray array];
    
    FMResultSet *rs = [db_ executeQuery: @"SELECT root_id, revid, embedded_object_uuid FROM proot_refs WHERE dest_root_id = ?", [aUUID dataValue]];
    while ([rs next])
    {
        ETUUID *root = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
        ETUUID *revUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
        ETUUID *embedded_object_uuid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
        
        COSearchResult *searchResult = [[COSearchResult alloc] init];
        searchResult.embeddedObjectUUID = embedded_object_uuid;
        searchResult.revision = [CORevisionID revisionWithBackinStoreUUID: root
                                                             revisionUUID: revUUID];
        [results addObject: searchResult];
        [searchResult release];
    }
    [rs close];
    
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
                
        // FIXME: switch back to version that posts on main thread above.
        [[NSNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
                                                            object: self
                                                          userInfo: userInfo];

        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
                                                                       object: [[self UUID] stringValue]
                                                                     userInfo: userInfo
                                                           deliverImmediately: NO];
    }
}

- (FMDatabase *) database
{
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

@end

NSString *COStorePersistentRootDidChangeNotification = @"COStorePersistentRootDidChangeNotification";
NSString *kCOPersistentRootUUID = @"COPersistentRootUUID";
NSString *kCOPersistentRootTransactionUUID = @"COPersistentRootTransactionUUID";
NSString *kCOStoreUUID = @"COStoreUUID";
NSString *kCOStoreURL = @"COStoreURL";