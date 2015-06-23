/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  November 2012
    License:  MIT  (see COPYING)
 */

#import "COSQLiteStore.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "CORevisionInfo.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>

#import "COItem.h"
#import "COSQLiteStore+Attachments.h"
#import "COSearchResult.h"
#import "COBasicHistoryCompaction.h"
#import "COBranchInfo.h"
#import "COJSONSerialization.h"
#import "COPersistentRootInfo.h"
#import "COStoreTransaction.h"
#import "COStoreAction.h"
#import "NSDistributedNotificationCenter.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

/* For dispatch_get_current_queue() deprecated on iOS (to prevent to people to 
   use it beside debugging) */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

NSString * const COStorePersistentRootsDidChangeNotification = @"COStorePersistentRootsDidChangeNotification";
NSString * const kCOStorePersistentRootTransactionIDs = @"COPersistentRootTransactionIDs";
NSString * const kCOStoreInsertedPersistentRoots = @"COStoreInsertedPersistentRoots";
NSString * const kCOStoreUpdatedPersistentRoots = @"COStoreUpdatedPersistentRoots";
NSString * const kCOStoreDeletedPersistentRoots = @"COStoreDeletedPersistentRoots";
NSString * const kCOStoreUUID = @"COStoreUUID";
NSString * const kCOStoreURL = @"COStoreURL";

NSString * const COPersistentRootAttributeExportSize = @"COPersistentRootAttributeExportSize";
NSString * const COPersistentRootAttributeUsedSize = @"COPersistentRootAttributeUsedSize";


@interface COSQLiteStore (AttachmentsPrivate)

- (NSArray *) attachments;
- (BOOL) deleteAttachment: (COAttachmentID *)hash;

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
	dispatch_sync(queue_, ^() {
		[db_ close];
		db_ = nil;
	});

#if !(TARGET_OS_IPHONE)
	// N.B.: We are using deployment target 10.7, so ARC does not manage libdispatch objects.
	// If we switch to deployment target 10.8, ARC will manage libdispatch objects automatically.
	// For GNUstep, ARC doesn't manage libdispatch objects since libobjc2 doesn't support it 
	// currently (we compile CoreObject with -DOS_OBJECT_USE_OBJC=0).
	dispatch_release(queue_);
#endif
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
     "uuid BLOB PRIMARY KEY NOT NULL, currentbranch BLOB, deleted BOOLEAN DEFAULT 0, transactionid INTEGER, metadata BLOB)"];
    
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS branches (uuid BLOB NOT NULL PRIMARY KEY, "
     "proot BLOB NOT NULL, current_revid BLOB NOT NULL, "
     "head_revid BLOB NOT NULL, metadata BLOB, deleted BOOLEAN DEFAULT 0, parentbranch BLOB)"];
    
	[db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS persistentroot_backingstores ("
     "uuid BLOB PRIMARY KEY NOT NULL, backingstore BLOB NOT NULL)"];
	
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

- (BOOL) commitStoreTransaction: (COStoreTransaction *)aTransaction
{
    __block BOOL ok = YES;
    
    assert(dispatch_get_current_queue() != queue_);
    
	NSMutableDictionary *txnIDForPersistentRoot = [[NSMutableDictionary alloc] init];
	NSMutableArray *insertedUUIDs = [[NSMutableArray alloc] init];
	NSMutableArray *deletedUUIDs = [[NSMutableArray alloc] init];
	
    dispatch_sync(queue_, ^() {
        [db_ beginTransaction];
        
		// update the last transaction field before we commit.

		// setup
		
        for (ETUUID *modifiedUUID in [aTransaction persistentRootUUIDs])
        {
			const BOOL isPresent = [db_ boolForQuery: @"SELECT COUNT(*) > 0 FROM persistentroots WHERE uuid = ?", [modifiedUUID dataValue]];
			const BOOL modifiesMutableState = [aTransaction touchesMutableStateForPersistentRootUUID: modifiedUUID];
			int64_t currentValue = [db_ int64ForQuery: @"SELECT transactionid FROM persistentroots WHERE uuid = ?", [modifiedUUID dataValue]];
			int64_t clientValue = [aTransaction oldTransactionIDForPersistentRoot: modifiedUUID];
			
			if (!modifiesMutableState)
				continue;
			
			if (clientValue != currentValue && isPresent)
			{
				ok = NO;
				NSLog(@"Transaction id mismatch for %@. DB had %d, transaction had %d",
					  modifiedUUID, (int)currentValue, (int)clientValue);
				[db_ rollback];
				return;
			}
			
			if (!isPresent)
				[insertedUUIDs addObject: modifiedUUID];
			
			int64_t newValue = clientValue + 1;
			
            [db_ executeUpdate: @"UPDATE persistentroots SET transactionid = ? WHERE uuid = ?",
			 @(newValue), [modifiedUUID dataValue]];
			
			txnIDForPersistentRoot[modifiedUUID] = @(newValue);
        }
        
		// perform actions
		
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
        
		// gather deleted persistent root UUIDs
		
		for (ETUUID *modifiedUUID in [aTransaction persistentRootUUIDs])
        {
			const BOOL isPresent = [db_ boolForQuery: @"SELECT COUNT(*) > 0 FROM persistentroots WHERE uuid = ?", [modifiedUUID dataValue]];
			
			if (!isPresent)
				[deletedUUIDs addObject: modifiedUUID];
        }
		
        if (!ok)
        {
            [db_ rollback];
            ok = NO;
        }
        else
        {
            ok = [db_ commit];
        }
    });
    
	if (ok)
	{
		[self postCommitNotificationsWithTransactionIDForPersistentRootUUID: txnIDForPersistentRoot
													insertedPersistentRoots: insertedUUIDs
													 deletedPersistentRoots: deletedUUIDs];
	}
	else
	{
		NSLog(@"Commit failed");
	}
	
    return ok;
}

- (NSArray *) allBackingUUIDs
{
    NSMutableArray *result = [NSMutableArray array];
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        FMResultSet *rs = [db_ executeQuery: @"SELECT DISTINCT backingstore FROM persistentroot_backingstores"];
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
		[self backingStoreForPersistentRootUUID: prootUUID createIfNotPresent: YES];

        result = [backingStore revisionInfosForBranchUUID: aBranchUUID
                                         headRevisionUUID: headRevUUID
                                                  options: options];
    });
    
    return result;
}

- (NSArray *)revisionInfosForBackingStoreOfPersistentRootUUID: (ETUUID *)aPersistentRoot
{
    __block NSArray *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
        COSQLiteStorePersistentRootBackingStore *backingStore =
		[self backingStoreForPersistentRootUUID: aPersistentRoot createIfNotPresent: YES];
		
        result = [backingStore revisionInfos];
    });
    
    return result;
}

- (ETUUID *) backingUUIDForPersistentRootUUID: (ETUUID *)aUUID
						   createIfNotPresent: (BOOL)createIfNotPresent
{
    assert(dispatch_get_current_queue() == queue_);
    
    ETUUID *backingUUID = [backingStoreUUIDForPersistentRootUUID_ objectForKey: aUUID];
    if (backingUUID == nil)
    {
        NSData *data = [db_ dataForQuery: @"SELECT backingstore FROM persistentroot_backingstores WHERE uuid = ?", [aUUID dataValue]];
        if (data != nil)
        {
            backingUUID = [ETUUID UUIDWithData: data];
        }
        else
        {
			if (createIfNotPresent)
			{
				backingUUID = aUUID;
			}
			else
			{
				return nil;
			}
        }
        
        [backingStoreUUIDForPersistentRootUUID_ setObject: backingUUID forKey: aUUID];
    }
    return backingUUID;
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForPersistentRootUUID: (ETUUID *)aUUID
															 createIfNotPresent: (BOOL)createIfNotPresent
{
    assert(dispatch_get_current_queue() == queue_);
    
	ETUUID *bsUUID = [self backingUUIDForPersistentRootUUID: aUUID
										 createIfNotPresent: createIfNotPresent];
	
	if (bsUUID == nil)
	{
		return nil;
	}
	
    return [self backingStoreForUUID: bsUUID
                               error: NULL];
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForUUID: (ETUUID *)aUUID error: (NSError **)error
{
    COSQLiteStorePersistentRootBackingStore *result = [backingStores_ objectForKey: aUUID];
    if (result == nil)
    {
        result = [[COSQLiteStorePersistentRootBackingStore alloc] initWithPersistentRootUUID: aUUID store: self useStoreDB: BACKING_STORES_SHARE_SAME_SQLITE_DB error: error];
        if (result == nil)
        {
            return nil;
        }
        
        [backingStores_ setObject: result forKey: aUUID];
    }
    return result;
}

- (NSString *)backingStorePathForUUID: (ETUUID *)aUUID
{
	return [[[self URL] path] stringByAppendingPathComponent: [NSString stringWithFormat: @"%@.sqlite", aUUID]];
}

- (void) deleteBackingStoreWithUUID: (ETUUID *)aUUID
{
#if BACKING_STORES_SHARE_SAME_SQLITE_DB == 1
	[db_ executeUpdate: [NSString stringWithFormat: @"DROP TABLE IF EXISTS `commits-%@`", aUUID]];
	[db_ executeUpdate: [NSString stringWithFormat: @"DROP TABLE IF EXISTS `metadata-%@`", aUUID]];
#else
	
	// FIXME: Test this
	
    {
        COSQLiteStorePersistentRootBackingStore *backing = [backingStores_ objectForKey: aUUID];
        if (backing != nil)
        {
            [backing close];
            [backingStores_ removeObjectForKey: aUUID];
        }
    }
    
    assert([[NSFileManager defaultManager] removeItemAtPath:
            [self backingStorePathForUUID: aUUID] error: NULL]);
#endif
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
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot createIfNotPresent: YES];
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
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot createIfNotPresent: YES];

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
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot
																				createIfNotPresent: YES];
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
        COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aPersistentRoot createIfNotPresent: YES];
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
    
    
    ETUUID *backingStoreUUID = [self backingUUIDForPersistentRootUUID: aPersistentRoot createIfNotPresent: YES];
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
        for (COAttachmentID *attachment in [itemToIndex attachments])
        {
			if ((id)attachment != [NSNull null])
			{
				[db_ executeUpdate: @"INSERT INTO attachment_refs(root_id, revid, attachment_hash) VALUES(?,?,?)",
				 backingUUIDData ,
				 [aRevision dataValue],
				 [attachment dataValue]];
			}
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
                           "INNER JOIN persistentroot_backingstores USING(backingstore)", aQuery];

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
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForPersistentRootUUID: aUUID
																			createIfNotPresent: YES];
    if (backing == nil)
    {
        return NO;
    }
    
	const int64_t parentRevid = [backing revidForUUID: aParent];
	const int64_t mergeParentRevid = [backing revidForUUID: aMergeParent];
	
	if (aParent != nil && parentRevid == -1)
	{
		NSLog(@"Parent revision not found: %@", aParent);
		// FIXME: If we're going to support writing revisions with missing parents
		// we should probably preserve the parent UUID?
	}
	if (aMergeParent != nil && mergeParentRevid == -1)
	{
		NSLog(@"Merge parent revision not found: %@", aMergeParent);
	}
	
    BOOL ok = [backing writeItemGraph: anItemTree
						 revisionUUID: aRevisionUUID
						 withMetadata: metadata
						   withParent: parentRevid
					  withMergeParent: mergeParentRevid
						   branchUUID: branch
				   persistentrootUUID: aUUID
								error: NULL];
    
    if (!ok)
    {
        NSLog(@"Error creating revision");
		return NO;
    }
    
	[self updateSearchIndexesForItemTree: anItemTree
				  revisionIDBeingWritten: aRevisionUUID
			  persistentRootBeingWritten: aUUID];
	
	return YES;
}

/** @taskunit persistent roots */

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
        BOOL deleted = NO;
		int64_t transactionID = -1;
        NSMutableDictionary *branchDict = [NSMutableDictionary dictionary];
		id persistentRootMetadata = nil;
        
        [db_ savepoint: @"persistentRootInfoForUUID"]; // N.B. The transaction is so the two SELECTs see the same DB. Needed?

        {
            FMResultSet *rs = [db_ executeQuery: @"SELECT currentbranch, deleted, transactionid, metadata FROM persistentroots WHERE uuid = ?", [aUUID dataValue]];
            if ([rs next])
            {
                currBranch = [rs dataForColumnIndex: 0] != nil
                    ? [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]
                    : nil;
                deleted = [rs boolForColumnIndex: 1];
				transactionID = [rs int64ForColumnIndex: 2];
				persistentRootMetadata = [self readMetadata: [rs dataForColumnIndex: 3]];
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
            FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, current_revid, head_revid, metadata, deleted, parentbranch FROM branches WHERE proot = ?", [aUUID dataValue]];
            while ([rs next])
            {
                ETUUID *branch = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
                ETUUID *currentRevid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
                ETUUID *headRevid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
                id branchMeta = [self readMetadata: [rs dataForColumnIndex: 3]];
                
                COBranchInfo *state = [[COBranchInfo alloc] init];
                state.UUID = branch;
				state.persistentRootUUID = aUUID;
                state.currentRevisionUUID = currentRevid;
				state.headRevisionUUID = headRevid;
                state.metadata = branchMeta;
                state.deleted = [rs boolForColumnIndex: 4];
				state.parentBranchUUID = [rs dataForColumnIndex: 5] != nil
					? [ETUUID UUIDWithData: [rs dataForColumnIndex: 5]]
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
		result.metadata = persistentRootMetadata;
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

- (NSDictionary *) readMetadata: (NSData*)data
{
    if (data != nil)
    {
        return COJSONObjectWithData(data, NULL);
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
        [garbage removeObject: [[COAttachmentID alloc] initWithData: [rs dataForColumnIndex: 0]]];
    }
    [rs close];

    for (COAttachmentID *hash in garbage)
    {
        if (![self deleteAttachment: hash])
        {
            return NO;
        }
    }
    return YES;
}

- (BOOL) finalizeDeletionsForPersistentRoots: (NSSet *)persistentRootUUIDs
									   error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(persistentRootUUIDs);
    COBasicHistoryCompaction *compaction = [COBasicHistoryCompaction new];
	
	compaction.finalizablePersistentRootUUIDs = persistentRootUUIDs;
	compaction.compactablePersistentRootUUIDs = persistentRootUUIDs;
	
	return [self compactHistory: compaction];
}


// Must not be wrapped in a transaction
- (BOOL) finalizeDeletionsForPersistentRoot: (ETUUID *)aRoot
                                      error: (NSError **)error
{
	return [self finalizeDeletionsForPersistentRoots: [NSSet setWithObject: aRoot]
	                                           error: error];
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

/**
 * We could put this code in a block passed to dispatch_async(dispatch_get_main_queue(), theBlock) 
 * and  call dispatch_async() in our  caller, but dispatch_get_main_queue() is only supported for 
 * Mac OS X (not on Linux or elsewhere). In future, GNUstep GUI could create a wrapper queue 
 * around NSRunLoop and set it as _dispatch_main_q.
 */
- (void) postCommitNotificationsWithUserInfo: (NSDictionary *)userInfo
{
	ETAssert([NSThread isMainThread]);
	ETAssert([NSPropertyListSerialization propertyList: userInfo
	                                  isValidForFormat: NSPropertyListXMLFormat_v1_0]);

	[[NSNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootsDidChangeNotification
	                                                    object: self
	                                                  userInfo: userInfo];

	[[NSDistributedNotificationCenter defaultCenter]
		postNotificationName: COStorePersistentRootsDidChangeNotification
		              object: [[self UUID] stringValue]
		            userInfo: userInfo
		  deliverImmediately: YES];
}

- (void) postCommitNotificationsWithTransactionIDForPersistentRootUUID: (NSDictionary *)txnIDForPersistentRoot
											   insertedPersistentRoots: (NSArray *)insertedUUIDs
												deletedPersistentRoots: (NSArray *)deletedUUIDs
{
	NSMutableDictionary *stringTxnIDForPersistentRoot = [[NSMutableDictionary alloc] init];
	NSMutableArray *deletedUUIDStrings = [NSMutableArray new];
	NSMutableArray *insertedUUIDStrings = [NSMutableArray new];
	
	for (ETUUID *persistentRootUUID in txnIDForPersistentRoot)
    {
		stringTxnIDForPersistentRoot[[persistentRootUUID stringValue]] = txnIDForPersistentRoot[persistentRootUUID];
	}
	for (ETUUID *persistentRootUUID in insertedUUIDs)
	{
		[insertedUUIDStrings addObject: persistentRootUUID.stringValue];
	}
	for (ETUUID *persistentRootUUID in deletedUUIDs)
	{
		[deletedUUIDStrings addObject: persistentRootUUID.stringValue];
	}
	
	NSDictionary *userInfo = @{kCOStorePersistentRootTransactionIDs : stringTxnIDForPersistentRoot,
							   kCOStoreDeletedPersistentRoots : deletedUUIDStrings,
							   kCOStoreInsertedPersistentRoots : insertedUUIDStrings,
							   kCOStoreUUID : [[self UUID] stringValue],
							   kCOStoreURL : [[self URL] absoluteString]};

	[self postCommitNotificationsWithUserInfo: userInfo];
}

- (FMDatabase *) database
{
    assert(dispatch_get_current_queue() == queue_);
    return db_;
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"<%@ %p - %@ (%@)>",
		NSStringFromClass([self class]), self, _uuid, url_];
}

- (NSString *) detailedDescription
{
    NSMutableString *result = [NSMutableString string];
    [result appendFormat: @"<COSQLiteStore at %@ (UUID: %@)\n", self.URL, self.UUID];
    for (ETUUID *backingUUID in [self allBackingUUIDs])
    {
        [result appendFormat: @"\t backing UUID %@ (containing ", backingUUID];
        
        for (ETUUID *persistentRoot in  [[NSSet setWithArray: [self persistentRootUUIDs]]
                                         objectsPassingTest: ^(id obj, BOOL *stop) {
                                             return [[self backingUUIDForPersistentRootUUID: obj
																		 createIfNotPresent: YES] isEqual: backingUUID];
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
        [db_ beginTransaction];
		
		NSMutableArray *backingStoresToClear = [NSMutableArray new];
		
		FMResultSet *rs = [db_ executeQuery: @"SELECT DISTINCT backingstore FROM persistentroot_backingstores"];
        while ([rs next])
        {
            ETUUID *uuid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
			[backingStoresToClear addObject: uuid];
        }
        [rs close];
		
		for (ETUUID *uuid in backingStoresToClear)
		{
			COSQLiteStorePersistentRootBackingStore *bs = [self backingStoreForUUID: uuid error: NULL];
			[bs clearBackingStore];
		}
		
        [db_ executeUpdate: @"DELETE FROM persistentroots"];
		[db_ executeUpdate: @"DELETE FROM persistentroot_backingstores"];
        [db_ executeUpdate: @"DELETE FROM branches"];
        [db_ executeUpdate: @"DELETE FROM proot_refs"];
        [db_ executeUpdate: @"DELETE FROM attachment_refs"];
        [db_ executeUpdate: @"DELETE FROM fts_docid_to_revisionid"];
        [db_ executeUpdate: @"DROP TABLE IF EXISTS fts"];
		[db_ executeUpdate: @"DROP TABLE IF EXISTS storeMetadata"];
        [db_ commit];
        
		[backingStores_ removeAllObjects];
		[backingStoreUUIDForPersistentRootUUID_ removeAllObjects];
		
        [self setupSchema];
    });
}

/** @taskunit Attributes */

- (NSDictionary *) attributesForPersistentRootWithUUID: (ETUUID *)aUUID
{
	__block NSDictionary *result = nil;
    
    assert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^(){
		COSQLiteStorePersistentRootBackingStore *bs = [self backingStoreForPersistentRootUUID: aUUID
																		   createIfNotPresent: NO];
		
		if (bs == nil)
			return;
		
		uint64_t exportsize = [bs fileSize];
		uint64_t usedsize = [[bs UUID] isEqual: aUUID] ? exportsize : 0;
		
		result = @{ COPersistentRootAttributeExportSize : @(exportsize),
				  COPersistentRootAttributeUsedSize : @(usedsize) };
	});
	return result;
}

- (void) testingRunBlockInStoreQueue: (void (^)())aBlock
{
	dispatch_sync(queue_, aBlock);
}

@end
