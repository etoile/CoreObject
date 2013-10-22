#import "COSQLiteStore.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
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

- (id)initWithURL: (NSURL*)aURL
{
	SUPERINIT;
    
    queue_ = dispatch_queue_create([[NSString stringWithFormat: @"COSQLiteStore-%p", self] UTF8String], NULL);
    
	url_ = aURL;
	backingStores_ = [[NSMutableDictionary alloc] init];
    backingStoreUUIDForPersistentRootUUID_ = [[NSMutableDictionary alloc] init];
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
        
        ok = [self setupSchema];
    });
    
    if (!ok)
    {
        return nil;
    }
    
	return self;
}

- (void) dealloc
{
    // N.B.: We are using deployment target 10.7, so ARC does not manage libdispatch objects.
    // If we switch to deployment target 10.8, ARC will manage libdispatch objects automatically.
    dispatch_release(queue_);
}

- (BOOL) setupSchema
{
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
            return NO;
        }
        
        _uuid =  [ETUUID UUIDWithData: [db_ dataForQuery: @"SELECT uuid FROM storeMetadata"]];
    }
    
    // Persistent Root and Branch tables
    
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS persistentroots ("
     "uuid BLOB PRIMARY KEY NOT NULL, backingstore BLOB NOT NULL, "
     "currentbranch BLOB, deleted BOOLEAN DEFAULT 0, transactionid INTEGER)"];
    
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS branches (uuid BLOB NOT NULL PRIMARY KEY, "
     "proot BLOB NOT NULL, initial_revid BLOB NOT NULL, current_revid BLOB NOT NULL, "
     "head_revid BLOB NOT NULL, metadata BLOB, deleted BOOLEAN DEFAULT 0, parentbranch BLOB)"];
    
    // FTS indexes & reference caching tables (in theory, could be regenerated - although not supported)
    
    /**
     * In inner_object_uuid in revid of backing store root_id, there was a reference to dest_root_id
     */
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS proot_refs (root_id BLOB, revid BOLB, inner_object_uuid BLOB, dest_root_id BLOB)"];
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
        return NO;
    }
    
    return YES;
}

- (NSURL*)URL
{
	return url_;
}

@synthesize UUID = _uuid;

/** @taskunit Transactions */

- (BOOL) beginTransactionWithError: (NSError **)error
{
	transaction_ = [[COStoreTransaction alloc] init];
    return YES;
}

- (BOOL) commitTransactionWithError: (NSError **)error
{
    return [self commitStoreTransaction: transaction_];
}

- (BOOL) commitStoreTransaction: (COStoreTransaction *)aTransaction
{
    __block BOOL ok = YES;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^() {
        [db_ beginTransaction];
        
		// update the last transaction field before we commit.
		
		NSMutableDictionary *txnIDForPersistentRoot = [[NSMutableDictionary alloc] init];
		
        for (ETUUID *modifiedUUID in [aTransaction persistentRootUUIDs])
        {
			const BOOL isPresent = [db_ boolForQuery: @"SELECT COUNT(*) > 0 FROM persistentroots WHERE uuid = ?", [modifiedUUID dataValue]];
			
			int64_t currentValue = [db_ int64ForQuery: @"SELECT transactionid FROM persistentroots WHERE uuid = ?", [modifiedUUID dataValue]];
			int64_t clientValue = [aTransaction oldTransactionIDForPersistentRoot: modifiedUUID];
			
			if (clientValue != currentValue && isPresent)
			{
				ok = NO;
				NSLog(@"Transaction id mismatch for %@. DB had %d, transaction had %d",
					  modifiedUUID, (int)currentValue, (int)clientValue);
				[db_ rollback];
				return;
			}
			
			int64_t newValue = clientValue + 1;
			
            [db_ executeUpdate: @"UPDATE persistentroots SET transactionid = ? WHERE uuid = ?",
			 @(newValue), [modifiedUUID dataValue]];
			
			txnIDForPersistentRoot[modifiedUUID] = @(newValue);
        }
        
        for (id<COStoreAction> op in aTransaction.operations)
        {
            BOOL opOk = [op execute: self inTransaction: aTransaction];
            if (!opOk)
            {
                NSLog(@"store action failed: %@", op);
				ok = NO;
				break;
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
                [self postCommitNotificationsWithTransactionIDForPersistentRootUUID: txnIDForPersistentRoot];
            }
            else
            {
                NSLog(@"Commit failed");
            }
        }
    });
    
    return ok;
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

- (ETUUID *)headRevisionUUIDForBranchUUID: (ETUUID *)aBranchUUID
{
	NILARG_EXCEPTION_TEST(aBranchUUID);

    __block ETUUID *revUUID = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT head_revid FROM branches WHERE uuid = ?",
            [aBranchUUID dataValue]];

        if ([rs next])
        {
            revUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            ETAssert([rs next] == NO);
        }

        [rs close];
    });
                  
	return revUUID;
}

- (NSArray *)revisionInfosForBranchUUID: (ETUUID *)aBranchUUID
                                options: (COBranchRevisionReadingOptions)options
{
	ETUUID *prootUUID = [self persistentRootUUIDForBranchUUID: aBranchUUID];
	ETUUID *headRevUUID = [self headRevisionUUIDForBranchUUID: aBranchUUID];

    __block NSArray *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backingStore =
		[self backingStoreForPersistentRootUUID: prootUUID];

        result = [backingStore revisionInfosForBranchUUID: aBranchUUID
                                         headRevisionUUID: headRevUUID
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

- (CORevisionInfo *) revisionInfoForRevisionUUID: (ETUUID *)aRevision
							  persistentRootUUID: (ETUUID *)aPersistentRoot
{
    NSParameterAssert(aRevision != nil);
    NSParameterAssert(aPersistentRoot != nil);
	
    __block CORevisionInfo *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot];
        result = [backing revisionInfoForRevisionUUID: aRevision];
    });
    
    return result;
}

- (COItemGraph *) partialItemGraphFromRevisionUUID: (ETUUID *)baseRevid
                                    toRevisionUUID: (ETUUID *)finalRevid
									persistentRoot: (ETUUID *)aPersistentRoot
{
    NSParameterAssert(baseRevid != nil);
    NSParameterAssert(finalRevid != nil);
    NSParameterAssert(aPersistentRoot != nil);
    
    __block COItemGraph *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot];

        result = [backing partialItemGraphFromRevid: [backing revidForUUID: baseRevid]
                                            toRevid: [backing revidForUUID: finalRevid]];
    });
    
    return result;
}

- (COItemGraph *) itemGraphForRevisionUUID: (ETUUID *)aRevisionUUID
							persistentRoot: (ETUUID *)aPersistentRoot
{
    NSParameterAssert(aRevisionUUID != nil);
    NSParameterAssert(aPersistentRoot != nil);
    
    __block COItemGraph *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot];
        result = [backing itemGraphForRevid: [backing revidForUUID: aRevisionUUID]];
    });
    return result;
}

- (ETUUID *) rootObjectUUIDForPersistentRoot: (ETUUID *)aPersistentRoot
{
    NSParameterAssert(aPersistentRoot != nil);
    
    __block ETUUID *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot];
        result = [backing rootUUID];
    });
    
    return result;
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
                 revisionIDBeingWritten: (ETUUID *)aRevision
			 persistentRootBeingWritten: (ETUUID *)aPersistentRoot
{
    assert(dispatch_get_current_queue() == queue_);
    
    [db_ savepoint: @"updateSearchIndexesForItemUUIDs"];
    
    
    ETUUID *backingStoreUUID = [self backingUUIDForPersistentRootUUID: aPersistentRoot];
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
            [db_ executeUpdate: @"INSERT INTO proot_refs(root_id, revid, inner_object_uuid, dest_root_id) VALUES(?,?,?,?)",
                backingUUIDData,
                [aRevision dataValue],
                [uuid dataValue],
                [referenced dataValue]];
        }
        
        // Look for attachments
        for (NSData *attachment in [itemToIndex attachments])
        {
            [db_ executeUpdate: @"INSERT INTO attachment_refs(root_id, revid, attachment_hash) VALUES(?,?,?)",
             backingUUIDData ,
             [aRevision dataValue],
             attachment];
        }
    }
    NSString *allItemsFtsContent = [ftsContent componentsJoinedByString: @" "];    
    
    [db_ executeUpdate: @"INSERT INTO fts_docid_to_revisionid(backingstore, revid) VALUES(?, ?)",
     backingUUIDData,
     [aRevision dataValue]];
    
    [db_ executeUpdate: @"INSERT INTO fts(docid, text) VALUES(?,?)",
     [NSNumber numberWithLongLong: [db_ lastInsertRowId]],
     allItemsFtsContent];
    
    [db_ releaseSavepoint: @"updateSearchIndexesForItemUUIDs"];
    
    //NSLog(@"Index text '%@' at revision id %@", allItemsFtsContent, aRevision);
    
    assert(![db_ hadError]);
}

- (NSArray *) searchResultsForQuery: (NSString *)aQuery
{
    NSMutableArray *result = [NSMutableArray array];
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, revid FROM "
                           "(SELECT backingstore, revid FROM fts_docid_to_revisionid WHERE docid IN (SELECT docid FROM fts WHERE text MATCH ?)) "
                           "INNER JOIN persistentroots USING(backingstore)", aQuery];

        while ([rs next])
        {
			COSearchResult *searchResult = [[COSearchResult alloc] init];
            searchResult.innerObjectUUID = nil;
            searchResult.revision = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
			searchResult.persistentRoot = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            [result addObject: searchResult];
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
    
    BOOL ok = [backing writeItemGraph: anItemTree
						 revisionUUID: aRevisionUUID
						 withMetadata: metadata
						   withParent: [backing revidForUUID: aParent]
					  withMergeParent: [backing revidForUUID: aMergeParent]
						   branchUUID: branch
				   persistentrootUUID: aUUID
								error: NULL];
    
    if (!ok)
    {
        NSLog(@"Error creating revision");
    }
    
	[self updateSearchIndexesForItemTree: anItemTree
				  revisionIDBeingWritten: aRevisionUUID
			  persistentRootBeingWritten: aUUID];
	
	return YES;
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
		int64_t transactionID = -1;
        NSMutableDictionary *branchDict = [NSMutableDictionary dictionary];

        
        [db_ savepoint: @"persistentRootInfoForUUID"]; // N.B. The transaction is so the two SELECTs see the same DB. Needed?

        {
            FMResultSet *rs = [db_ executeQuery: @"SELECT currentbranch, backingstore, deleted, transactionid FROM persistentroots WHERE uuid = ?", [aUUID dataValue]];
            if ([rs next])
            {
                currBranch = [rs dataForColumnIndex: 0] != nil
                    ? [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]
                    : nil;
                backingUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
                deleted = [rs boolForColumnIndex: 2];
				transactionID = [rs int64ForColumnIndex: 3];
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
            FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, initial_revid, current_revid, head_revid, metadata, deleted, parentbranch FROM branches WHERE proot = ?", [aUUID dataValue]];
            while ([rs next])
            {
                ETUUID *branch = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
                ETUUID *initialRevid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
                ETUUID *currentRevid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
                ETUUID *headRevid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 3]];
                id branchMeta = [self readMetadata: [rs dataForColumnIndex: 4]];
                
                COBranchInfo *state = [[COBranchInfo alloc] init];
                state.UUID = branch;
				state.persistentRootUUID = aUUID;
                state.initialRevisionUUID = initialRevid;
                state.currentRevisionUUID = currentRevid;
				state.headRevisionUUID = headRevid;
                state.metadata = branchMeta;
                state.deleted = [rs boolForColumnIndex: 5];
				state.parentBranchUUID = [rs dataForColumnIndex: 6] != nil
					? [ETUUID UUIDWithData: [rs dataForColumnIndex: 6]]
					: nil;
                
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
		result.transactionID = transactionID;
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
        FMResultSet *rs = [db_ executeQuery: @"SELECT root_id, revid, inner_object_uuid FROM proot_refs WHERE dest_root_id = ?", [aUUID dataValue]];
        while ([rs next])
        {
            ETUUID *root = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            ETUUID *revUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
            ETUUID *inner_object_uuid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
            
            COSearchResult *searchResult = [[COSearchResult alloc] init];
            searchResult.innerObjectUUID = inner_object_uuid;
            searchResult.revision = revUUID;
			searchResult.persistentRoot = root;
            [results addObject: searchResult];
        }
        [rs close];
    });
    
    return results;
}

- (void) postCommitNotificationsWithTransactionIDForPersistentRootUUID: (NSDictionary *)txnIDForPersistentRoot
{
    for (ETUUID *persistentRoot in txnIDForPersistentRoot)
    {
        NSDictionary *userInfo = @{kCOPersistentRootUUID : [persistentRoot stringValue],
                                   kCOPersistentRootTransactionID : txnIDForPersistentRoot[persistentRoot],
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
            ETUUID *revisionID = [bs revisionUUIDForRevid: i];
            if (revisionID == nil)
            {
                break;
            }
            [result appendFormat: @"\t\t %lld (UUID: %@)\n", (long long int)i, revisionID];
        }
    }
    return result;
}

- (void) clearStore
{
    dispatch_sync(queue_, ^() {
        [db_ beginDeferredTransaction];        
        [db_ executeUpdate: @"DROP TABLE IF EXISTS persistentroots"];
        [db_ executeUpdate: @"DROP TABLE IF EXISTS branches"];
        [db_ executeUpdate: @"DROP TABLE IF EXISTS proot_refs"];
        [db_ executeUpdate: @"DROP TABLE IF EXISTS attachment_refs"];
        [db_ executeUpdate: @"DROP TABLE IF EXISTS fts_docid_to_revisionid"];
        [db_ executeUpdate: @"DROP TABLE IF EXISTS fts"];
        [db_ commit];
        
        [self setupSchema];
    });
}

@end

NSString *COStorePersistentRootDidChangeNotification = @"COStorePersistentRootDidChangeNotification";
NSString *kCOPersistentRootUUID = @"COPersistentRootUUID";
NSString *kCOPersistentRootTransactionID = @"COPersistentRootTransactionID";
NSString *kCOStoreUUID = @"COStoreUUID";
NSString *kCOStoreURL = @"COStoreURL";
