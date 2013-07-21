#import "COSQLiteStore.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "CORevisionID.h"
#import "CORevisionInfo.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>

#import "COItem.h"
#import "COSQLiteStore+Attachments.h"
#import "COSearchResult.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation COPersistentRootInfo

@synthesize UUID = uuid_;
@synthesize currentBranchUUID = currentBranch_;
@synthesize branchForUUID = branchForUUID_;
@synthesize changeCount = _changeCount;
- (void) dealloc
{
    [uuid_ release];
    [branchForUUID_ release];
    [currentBranch_ release];
    [super dealloc];
}

- (NSSet *) branchUUIDs
{
    return [NSSet setWithArray: [branchForUUID_ allKeys]];
}

- (COBranchInfo *)branchInfoForUUID: (ETUUID *)aUUID
{
    return [branchForUUID_ objectForKey: aUUID];
}
- (COBranchInfo *)currentBranchInfo
{
    return [self branchInfoForUUID: [self currentBranchUUID]];
}

@end

@implementation COBranchInfo

@synthesize UUID = uuid_;
@synthesize headRevisionID = headRevisionId_;
@synthesize tailRevisionID = tailRevisionId_;
@synthesize currentRevisionID = currentRevisionId_;
@synthesize deleted = deleted_;
@synthesize metadata = metadata_;

- (void) dealloc
{
    [uuid_ release];
    [headRevisionId_ release];
    [tailRevisionId_ release];
    [currentRevisionId_ release];
    [metadata_ release];
    [super dealloc];
}

@end


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
    notificationUserInfoToPostForPersistentRootUUID_ = [[NSMutableDictionary alloc] init];
    
	BOOL isDirectory;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: [url_ path]
													   isDirectory: &isDirectory];
	
	if (!exists)
	{
		if (![[NSFileManager defaultManager] createDirectoryAtPath: [url_ path]
                                       withIntermediateDirectories: YES
                                                        attributes: nil
                                                             error: NULL])
		{
			[self release];
			[NSException raise: NSGenericException
						format: @"Error creating store at %@", [url_ path]];
			return nil;
		}
	}
	// assume it is a valid store if it exists... (may not be of course)
	
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
        
        if ([@"wal" isEqualToString: result])
        {
            // The default setting is synchronous=FULL, but according to:
            // http://www.sqlite.org/pragma.html#pragma_synchronous
            // NORMAL is just as safe w.r.t. consistency. FULL only guarantees that the commits
            // will block until data is safely on disk, which we don't need.
            [db_ executeUpdate: @"PRAGMA synchronous=NORMAL"];
        }
        else
        {
            NSLog(@"Enabling WAL mode failed.");
        }
    }    
    
    // Set up schema
    
    [db_ beginTransaction];
    
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
    
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS persistentroots (root_id INTEGER PRIMARY KEY, "
     "uuid BLOB, backingstore BLOB, currentbranch INTEGER, deleted BOOLEAN DEFAULT 0, changecount INTEGER)"];
    
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS branches (branch_id INTEGER PRIMARY KEY, "
     "uuid BLOB, proot INTEGER, head_revid INTEGER, tail_revid INTEGER, current_revid INTEGER, metadata BLOB, deleted BOOLEAN DEFAULT 0)"];

    [db_ executeUpdate: @"CREATE INDEX IF NOT EXISTS persistentroots_uuid_index ON persistentroots(uuid)"];
    [db_ executeUpdate: @"CREATE INDEX IF NOT EXISTS branches_proot_index ON branches(proot)"];

    // FTS indexes & reference caching tables (in theory, could be regenerated - although not supported)
    
    /**
     * In embedded_object_uuid in revid of backing store root_id, there was a reference to dest_root_id
     */
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS proot_refs (root_id BLOB, revid INTEGER, embedded_object_uuid BLOB, dest_root_id BLOB)"];
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS attachment_refs (root_id BLOB, revid INTEGER, attachment_hash BLOB)"];    
    
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
     "docid INTEGER PRIMARY KEY, backingstore BLOB, revid INTEGER)"];
    
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
    [notificationUserInfoToPostForPersistentRootUUID_ release];
    [_uuid release];
	[super dealloc];
}

- (NSURL*)URL
{
	return url_;
}

@synthesize UUID = _uuid;

- (NSNumber *) rootIdForPersistentRootUUID: (ETUUID *)aUUID
{
    return [db_ numberForQuery: @"SELECT root_id FROM persistentroots WHERE uuid = ?", [aUUID dataValue]];
}

- (ETUUID *) UUIDForPersistentRootId: (int64_t)anId
{
    NSData *backingstore = [db_ dataForQuery: @"SELECT uuid FROM persistentroots WHERE root_id = ?", [NSNumber numberWithLongLong: anId]];
    
    return [ETUUID UUIDWithData: backingstore];
}

/** @taskunit Transactions */

- (BOOL) beginTransactionWithError: (NSError **)error
{
    return [db_ beginTransaction];
}
- (BOOL) commitTransactionWithError: (NSError **)error
{
    BOOL ok = [db_ commit];
    
    if (ok)
    {
        [self postCommitNotifications];
    }
    return ok;
}

- (NSArray *) allBackingUUIDs
{
    NSMutableArray *result = [NSMutableArray array];
    FMResultSet *rs = [db_ executeQuery: @"SELECT UNIQUE backingstore FROM persistentroots"];
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
    return [self backingStoreForUUID:
            [self backingUUIDForPersistentRootUUID: aUUID]];
}

- (NSString *) backingStorePathForUUID: (ETUUID *)aUUID
{
    return [[url_ path] stringByAppendingPathComponent: [aUUID stringValue]];
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForUUID: (ETUUID *)aUUID
{
    COSQLiteStorePersistentRootBackingStore *result = [backingStores_ objectForKey: aUUID];
    if (result == nil)
    {
        result = [[COSQLiteStorePersistentRootBackingStore alloc] initWithPath:
                    [self backingStorePathForUUID: aUUID]];
        [backingStores_ setObject: result forKey: aUUID];
        [result release];
    }
    return result;
}

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForRevisionID: (CORevisionID *)aToken
{
    return [self backingStoreForUUID: [aToken backingStoreUUID]];
}

- (void) deleteBackingStoreWithUUID: (ETUUID *)aUUID
{
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
}

/** @taskunit reading states */

- (CORevisionInfo *) revisionInfoForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    return [backing revisionForID: aToken];
}

- (COItemGraph *) partialContentsFromRevisionID: (CORevisionID *)baseRevid
                                  toRevisionID: (CORevisionID *)finalRevid
{
    NSParameterAssert(baseRevid != nil);
    NSParameterAssert(finalRevid != nil);
    NSParameterAssert([[baseRevid backingStoreUUID] isEqual: [finalRevid backingStoreUUID]]);
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: baseRevid];
    COItemGraph *result = [backing partialItemTreeFromRevid: [baseRevid revisionIndex]
                                                   toRevid: [finalRevid revisionIndex]];
    return result;
}

- (COItemGraph *) contentsForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    COItemGraph *result = [backing itemTreeForRevid: [aToken revisionIndex]];
    return result;
}

- (ETUUID *) rootObjectUUIDForRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    return [backing rootUUIDForRevid: [aToken revisionIndex]];
}

- (COItem *) item: (ETUUID *)anitem atRevisionID: (CORevisionID *)aToken
{
    NSParameterAssert(aToken != nil);
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForRevisionID: aToken];
    COItemGraph *tree = [backing itemTreeForRevid: [aToken revisionIndex] restrictToItemUUIDs: S(anitem)];
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
                              inItemTree: (COItemGraph *)anItemTree
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
                [NSNumber numberWithLongLong: [aRevision revisionIndex]],
                [uuid dataValue],
                [referenced dataValue]];
        }
        
        // Look for attachments
        for (NSData *attachment in [itemToIndex attachments])
        {
            [db_ executeUpdate: @"INSERT INTO attachment_refs(root_id, revid, attachment_hash) VALUES(?,?,?)",
             backingUUIDData ,
             [NSNumber numberWithLongLong: [aRevision revisionIndex]],
             attachment];
        }
    }
    NSString *allItemsFtsContent = [ftsContent componentsJoinedByString: @" "];    
    
    [db_ executeUpdate: @"INSERT INTO fts_docid_to_revisionid(backingstore, revid) VALUES(?, ?)",
     backingUUIDData,
     [NSNumber numberWithLongLong: [aRevision revisionIndex]]];
    
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
        CORevisionID *revId = [[CORevisionID alloc] initWithPersistentRootBackingStoreUUID: [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]]
                                                                             revisionIndex: [rs int64ForColumnIndex: 1]];
        [result addObject: revId];
        [revId release];
    }
    [rs close];
    return result;
}

- (CORevisionID *) writeContents: (COItemGraph *)anItemTree
                    withMetadata: (NSDictionary *)metadata
                parentRevisionID: (CORevisionID *)aParent
                   modifiedItems: (NSArray*)modifiedItems // array of COUUID
                           error: (NSError **)error
{
    [self validateRevision: aParent];
    
    NSParameterAssert(anItemTree != nil);
    NSParameterAssert(aParent != nil);
    
    return [self writeItemTree: anItemTree
                  withMetadata: metadata
               withParentRevid: [aParent revisionIndex]
        inBackingStoreWithUUID: [aParent backingStoreUUID]
                 modifiedItems: modifiedItems];
}

- (CORevisionID *) writeItemTreeWithNoParent: (COItemGraph *)anItemTree
                                withMetadata: (NSDictionary *)metadata
                      inBackingStoreWithUUID: (ETUUID *)aBacking
{
    return [self writeItemTree: anItemTree
                  withMetadata: metadata
               withParentRevid: -1
        inBackingStoreWithUUID: aBacking
                 modifiedItems: nil];
}


- (CORevisionID *) writeItemTree: (COItemGraph *)anItemTree
                    withMetadata: (NSDictionary *)metadata
                 withParentRevid: (int64_t)parentRevid
          inBackingStoreWithUUID: (ETUUID *)aBacking
                   modifiedItems: (NSArray*)modifiedItems // array of COUUID
{
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: aBacking];
    const int64_t revid = [backing writeItemTree: anItemTree
                                    withMetadata: metadata
                                      withParent: parentRevid
                                   modifiedItems: modifiedItems];
    
    assert(revid >= 0);
    CORevisionID *revidObject = [CORevisionID revisionWithBackinStoreUUID: aBacking
                                                            revisionIndex: revid];
    
    [self updateSearchIndexesForItemUUIDs: modifiedItems
                               inItemTree: anItemTree
                   revisionIDBeingWritten: revidObject];
    
    return revidObject;
}

/** @taskunit persistent roots */

- (BOOL) checkAndUpdateChangeCount: (int64_t *)aChangeCount forPersistentRootId: (NSNumber *)root_id
{
    const int64_t user = *aChangeCount;
    const int64_t actual = [db_ int64ForQuery: @"SELECT changecount FROM persistentroots WHERE root_id = ?", root_id];
    
    if (actual == user)
    {
        const int64_t newCount = user + 1;
        
        [db_ executeUpdate: @"UPDATE persistentroots SET changecount = ? WHERE root_id = ?",
         [NSNumber numberWithLongLong: newCount],
         root_id];
        
        *aChangeCount = newCount;
        return YES;
    }
    return NO;
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
    NILARG_EXCEPTION_TEST(aUUID);
    
    ETUUID *currBranch = nil;
    ETUUID *backingUUID = nil;
    BOOL deleted = NO;
    int64_t changecount = 0;
    
    [db_ savepoint: @"persistentRootInfoForUUID"]; // N.B. The transaction is so the two SELECTs see the same DB. Needed?
    
    NSNumber *root_id = [self rootIdForPersistentRootUUID: aUUID];
    
    {
        FMResultSet *rs = [db_ executeQuery: @"SELECT (SELECT uuid FROM branches WHERE branch_id = currentbranch),"
                                                    " backingstore, deleted, changecount FROM persistentroots WHERE root_id = ?", root_id];
        if ([rs next])
        {
            currBranch = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            backingUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 1]];
            deleted = [rs boolForColumnIndex: 2];
            changecount = [rs int64ForColumnIndex: 3];
        }
        else
        {
            [rs close];
            [db_ commit];
            return nil;
        }
        [rs close];
    }
    
    NSMutableDictionary *branchDict = [NSMutableDictionary dictionary];
    
    {
        FMResultSet *rs = [db_ executeQuery: @"SELECT uuid, head_revid, tail_revid, current_revid, metadata, deleted FROM branches WHERE proot = ?",  root_id];
        while ([rs next])
        {
            ETUUID *branch = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
            CORevisionID *headRevid = [CORevisionID revisionWithBackinStoreUUID: backingUUID
                                                                  revisionIndex: [rs int64ForColumnIndex: 1]];
            CORevisionID *tailRevid = [CORevisionID revisionWithBackinStoreUUID: backingUUID
                                                                  revisionIndex: [rs int64ForColumnIndex: 2]];
            CORevisionID *currentRevid = [CORevisionID revisionWithBackinStoreUUID: backingUUID
                                                                     revisionIndex: [rs int64ForColumnIndex: 3]];
            id branchMeta = [self readMetadata: [rs dataForColumnIndex: 4]];            
            
            COBranchInfo *state = [[[COBranchInfo alloc] init] autorelease];
            state.UUID = branch;
            state.headRevisionID = headRevid;
            state.tailRevisionID = tailRevid;
            state.currentRevisionID = currentRevid;
            state.metadata = branchMeta;
            state.deleted = [rs boolForColumnIndex: 5];
            
            [branchDict setObject: state forKey: branch];
        }
        [rs close];
    }
    
    [db_ releaseSavepoint: @"persistentRootInfoForUUID"];

    COPersistentRootInfo *result = [[[COPersistentRootInfo alloc] init] autorelease];
    result.UUID = aUUID;
    result.branchForUUID = branchDict;
    result.currentBranchUUID = currBranch;
    result.changeCount = changecount;
    
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
                                               metadata: (NSDictionary *)metadata
                                                  error: (NSError **)error
{
    [db_ savepoint: @"createPersistentRootWithUUID"];
    
    [db_ executeUpdate: @"INSERT INTO persistentroots (uuid, "
           "backingstore, currentbranch, deleted) VALUES(?,?,NULL,0)",
           [uuid dataValue],
           [[revId backingStoreUUID] dataValue]];

    const int64_t root_id = [db_ lastInsertRowId];
    
    [db_ executeUpdate: @"INSERT INTO branches (uuid, proot, head_revid, tail_revid, current_revid, metadata, deleted) VALUES(?,?,?,?,?,?,0)",
           [aBranchUUID dataValue],
           [NSNumber numberWithLongLong: root_id],
           [NSNumber numberWithLongLong: [revId revisionIndex]],
           [NSNumber numberWithLongLong: [revId revisionIndex]],
           [NSNumber numberWithLongLong: [revId revisionIndex]],
           nil];
    
    const int64_t branch_id = [db_ lastInsertRowId];
    
    [db_ executeUpdate: @"UPDATE persistentroots SET currentbranch = ? WHERE root_id = ?",
      [NSNumber numberWithLongLong: branch_id],
      [NSNumber numberWithLongLong: root_id]];

    [db_ releaseSavepoint: @"createPersistentRootWithUUID"];
    
    // Return info
    
    COBranchInfo *branch = [[[COBranchInfo alloc] init] autorelease];
    branch.UUID = aBranchUUID;
    branch.headRevisionID = revId;
    branch.tailRevisionID = revId;
    branch.currentRevisionID = revId;
    branch.metadata = nil;
    branch.deleted = NO;
                                  
    COPersistentRootInfo *plist = [[[COPersistentRootInfo alloc] init] autorelease];
    plist.UUID = uuid;
    plist.branchForUUID = D(branch, aBranchUUID);
    plist.currentBranchUUID = aBranchUUID;

    return plist;
}

- (COPersistentRootInfo *) createPersistentRootWithInitialContents: (id<COItemGraph>)contents
                                                              UUID: (ETUUID *)persistentRootUUID
                                                        branchUUID: (ETUUID *)aBranchUUID
                                                          metadata: (NSDictionary *)metadata
                                                             error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(contents);
    NILARG_EXCEPTION_TEST(persistentRootUUID);
    NILARG_EXCEPTION_TEST(aBranchUUID);
    
    CORevisionID *revId = [self writeItemTreeWithNoParent: contents
                                             withMetadata: [NSDictionary dictionary]
                                   inBackingStoreWithUUID: persistentRootUUID];
    
    return [self createPersistentRootWithUUID: persistentRootUUID
                                   branchUUID: aBranchUUID
                                       isCopy: NO
                              initialRevision: revId
                                     metadata: metadata
                                        error: error];
}

- (COPersistentRootInfo *) createPersistentRootWithInitialRevision: (CORevisionID *)aRevision
                                                              UUID: (ETUUID *)persistentRootUUID
                                                        branchUUID: (ETUUID *)aBranchUUID
                                                          metadata: (NSDictionary *)metadata
                                                             error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aRevision);
    NILARG_EXCEPTION_TEST(persistentRootUUID);
    NILARG_EXCEPTION_TEST(aBranchUUID);
    [self validateRevision: aRevision];
    
    return [self createPersistentRootWithUUID: persistentRootUUID
                                   branchUUID: aBranchUUID
                                       isCopy: YES
                              initialRevision: aRevision
                                     metadata: metadata
                                        error: error];
}

- (BOOL) deletePersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = NO;
    NSNumber *root_id = [self rootIdForPersistentRootUUID: aRoot];
    if (root_id != nil)
    {
        ok = [db_ executeUpdate: @"UPDATE persistentroots SET deleted = 1 WHERE root_id = ?", root_id];
    }
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: YES];
    }
    
    return ok;
}

- (BOOL) undeletePersistentRoot: (ETUUID *)aRoot
                          error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = NO;
    NSNumber *root_id = [self rootIdForPersistentRootUUID: aRoot];
    if (root_id != nil)
    {
        ok = [db_ executeUpdate: @"UPDATE persistentroots SET deleted = 0 WHERE root_id = ?", root_id];
    }
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: NO];
    }
    
    return ok;
}

- (BOOL) setCurrentBranch: (ETUUID *)aBranch
		forPersistentRoot: (ETUUID *)aRoot
                 error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    [db_ savepoint: @"setCurrentBranch"];
    
    BOOL ok;
    NSNumber *root_id = [self rootIdForPersistentRootUUID: aRoot];
    NSNumber *branch_id = [db_ numberForQuery: @"SELECT branch_id FROM branches WHERE proot = ? AND uuid = ? AND deleted = 0", root_id, [aBranch dataValue]];
    if (branch_id != nil)
    {
        ok = [db_ executeUpdate: @"UPDATE persistentroots SET currentbranch = ? WHERE root_id = ?",
                   branch_id,
                   root_id];
    }
    else
    {
        NSLog(@"WARNING, %@ failed", NSStringFromSelector(_cmd));
        ok = NO;
    }
    
    [db_ releaseSavepoint: @"setCurrentBranch"];
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: NO];
    }
    return ok;
}

- (BOOL) createBranchWithUUID: (ETUUID *)branchUUID
              initialRevision: (CORevisionID *)revId
            forPersistentRoot: (ETUUID *)aRoot
                        error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(branchUUID);
    NILARG_EXCEPTION_TEST(revId);
    NILARG_EXCEPTION_TEST(aRoot);
    [self validateRevision: revId forPersistentRoot: aRoot];
    
    NSNumber *root_id = [self rootIdForPersistentRootUUID: aRoot];
    BOOL ok = [db_ executeUpdate: @"INSERT INTO branches (uuid, proot, head_revid, tail_revid, current_revid, metadata, deleted) VALUES(?,?,?,?,?,?,0)",
     [branchUUID dataValue],
     root_id,
     [NSNumber numberWithLongLong: [revId revisionIndex]],
     [NSNumber numberWithLongLong: [revId revisionIndex]],
     [NSNumber numberWithLongLong: [revId revisionIndex]],
     nil];    
  
    if (!ok)
    {
        branchUUID = nil;
    }
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: NO];
    }
    
    return ok;
}

- (void) validateRevision: (CORevisionID*)aRev
{
    if (aRev == nil)
    {
        return;
    }
    
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: [aRev backingStoreUUID]];
    
    if (![backing hasRevid: [aRev revisionIndex]])
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
               headRevision: (CORevisionID*)headRev
               tailRevision: (CORevisionID*)tailRev
                  forBranch: (ETUUID *)aBranch
           ofPersistentRoot: (ETUUID *)aRoot
         currentChangeCount: (int64_t *)aChangeCountInOut
                      error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    [self validateRevision: currentRev forPersistentRoot: aRoot];
    [self validateRevision: headRev forPersistentRoot: aRoot];
    [self validateRevision: tailRev forPersistentRoot: aRoot];
    
    [db_ savepoint: @"setCurrentRevision"];

    NSNumber *root_id = [self rootIdForPersistentRootUUID: aRoot];
    if (![self checkAndUpdateChangeCount: aChangeCountInOut forPersistentRootId: root_id])
    {
        NSLog(@"changeCount incorrect");
        [db_ releaseSavepoint: @"setCurrentRevision"];
        return NO;
    }
    
    NSData *branchData = [aBranch dataValue];
    
    if (currentRev != nil)
    {
        [db_ executeUpdate: @"UPDATE branches SET current_revid = ? WHERE uuid = ?",
                [NSNumber numberWithLongLong: [currentRev revisionIndex]],
                branchData];
    }
    if (headRev != nil)
    {
        [db_ executeUpdate: @"UPDATE branches SET head_revid = ? WHERE uuid = ?",
                [NSNumber numberWithLongLong: [headRev revisionIndex]],
                branchData];
    }
    if (tailRev != nil)
    {
        [db_ executeUpdate: @"UPDATE branches SET tail_revid = ? WHERE uuid = ?",
                [NSNumber numberWithLongLong: [tailRev revisionIndex]],
                branchData];
    }

    BOOL ok = [db_ releaseSavepoint: @"setCurrentRevision"];
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: NO];
    }
    
    return ok;
}


- (BOOL) deleteBranch: (ETUUID *)aBranch
     ofPersistentRoot: (ETUUID *)aRoot
                error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = [db_ executeUpdate: @"UPDATE branches SET deleted = 1 WHERE uuid = ? AND branch_id != (SELECT currentbranch FROM persistentroots WHERE root_id = proot)",
               [aBranch dataValue]];
    if (ok)
    {
        ok = [db_ changes] > 0;
    }
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: NO];
    }
    
    return ok;
}

- (BOOL) undeleteBranch: (ETUUID *)aBranch
       ofPersistentRoot: (ETUUID *)aRoot
                  error: (NSError **)error
{
    NILARG_EXCEPTION_TEST(aBranch);
    NILARG_EXCEPTION_TEST(aRoot);
    
    BOOL ok = [db_ executeUpdate: @"UPDATE branches SET deleted = 0 WHERE uuid = ?",
               [aBranch dataValue]];
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: NO];
    }
    
    return ok;
}

- (BOOL) setMetadata: (NSDictionary *)meta
           forBranch: (ETUUID *)aBranch
    ofPersistentRoot: (ETUUID *)aRoot
               error: (NSError **)error
{
    NSData *data = [self writeMetadata: meta];    
    BOOL ok = [db_ executeUpdate: @"UPDATE branches SET metadata = ? WHERE uuid = ?",
               data,
               [aBranch dataValue]];
    
    if (ok)
    {
        [self recordCommitNotificationsWithPersistentRootUUID: aRoot
                                                  changeCount: 0
                                                      deleted: NO];
    }
    
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
    COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: backingUUID];
    //NSNumber *backingId = [self rootIdForPersistentRootUUID: backingUUID];
    NSData *backingUUIDData = [backingUUID dataValue];
    
    [db_ beginTransaction];
    
    // Delete branches / the persistent root
    
    [db_ executeUpdate: @"DELETE FROM branches WHERE proot IN (SELECT root_id FROM persistentroots WHERE deleted = 1 AND backingstore = ?)", backingUUIDData];
    [db_ executeUpdate: @"DELETE FROM branches WHERE deleted = 1 AND proot IN (SELECT root_id FROM persistentroots WHERE backingstore = ?)", backingUUIDData];
    [db_ executeUpdate: @"DELETE FROM persistentroots WHERE deleted = 1 AND backingstore = ?", backingUUIDData];
    
    NSMutableIndexSet *keptRevisions = [NSMutableIndexSet indexSet];
    
    FMResultSet *rs = [db_ executeQuery: @"SELECT "
                                            "branches.head_revid, "
                                            "branches.tail_revid "
                                            "FROM persistentroots "
                                            "INNER JOIN branches ON persistentroots.root_id = branches.proot "
                                            "WHERE persistentroots.backingstore = ?", backingUUIDData];
    while ([rs next])
    {
        const int64_t head = [rs int64ForColumnIndex: 0];
        const int64_t tail = [rs int64ForColumnIndex: 1];
        
        NSIndexSet *revs = [backing revidsFromRevid: tail toRevid: head];        
        [keptRevisions addIndexes: revs];
    }
    [rs close];
    
    // Now for each index set in deletedRevisionsForBackingStore, subtract the index set
    // in keptRevisionsForBackingStore
    
    NSMutableIndexSet *deletedRevisions = [NSMutableIndexSet indexSet];
    [deletedRevisions addIndexes: [backing revidsUsedRange]];
    [deletedRevisions removeIndexes: keptRevisions];
    
    for (NSUInteger i = [deletedRevisions firstIndex]; i != NSNotFound; i = [deletedRevisions indexGreaterThanIndex: i])
    {
        
        [db_ executeUpdate: @"DELETE FROM attachment_refs WHERE root_id = ? AND revid = ?",
         [backingUUID dataValue],
         [NSNumber numberWithLongLong: i]];
        
        // FIXME: FTS, proot_refs
    }
    
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
        const int64_t revid = [rs int64ForColumnIndex: 1];
        ETUUID *embedded_object_uuid = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
        
        COSearchResult *searchResult = [[COSearchResult alloc] init];
        searchResult.embeddedObjectUUID = embedded_object_uuid;
        searchResult.revision = [CORevisionID revisionWithBackinStoreUUID: root
                                                            revisionIndex: revid];
        [results addObject: searchResult];
        [searchResult release];
    }
    [rs close];
    
    return results;
}

- (void) recordCommitNotificationsWithPersistentRootUUID: (ETUUID *)aUUID
                                             changeCount: (int64_t)changeCount
                                                 deleted: (BOOL)deleted
{
    NSDictionary *userInfo = D([aUUID stringValue], kCOPersistentRootUUID,
                               [NSNumber numberWithLongLong: changeCount], kCOPersistentRootChangeCount,
                               [NSNumber numberWithBool: deleted], kCOPersistentRootDeleted,
                               [[self UUID] stringValue], kCOStoreUUID,
                               [[self URL] absoluteString], kCOStoreURL);
    
    [notificationUserInfoToPostForPersistentRootUUID_ setObject: userInfo forKey: aUUID];
    
    if (![db_ inTransaction])
    {
        [self postCommitNotifications];
    }
}
- (void) mainThreadPostLocalNotification: (NSDictionary *)userInfo
{
    // TODO: Check if we need to use NSNotificationQueue?
    [[NSNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
                                                        object: self
                                                      userInfo: userInfo];
}

- (void) postCommitNotifications
{
    for (NSDictionary *userInfo in [notificationUserInfoToPostForPersistentRootUUID_ allValues])
    {
        //NSLog(@"store %@ posting notif: %@", [self UUID], userInfo);
        
        [self performSelectorOnMainThread: @selector(mainThreadPostLocalNotification:)
                               withObject: userInfo
                            waitUntilDone: NO];
        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
                                                                       object: [[self UUID] stringValue]
                                                                     userInfo: userInfo
                                                           deliverImmediately: NO];
    }
    [notificationUserInfoToPostForPersistentRootUUID_ removeAllObjects];
}

@end

NSString *COStorePersistentRootDidChangeNotification = @"COStorePersistentRootDidChangeNotification";
NSString *kCOPersistentRootUUID = @"COPersistentRootUUID";
NSString *kCOPersistentRootChangeCount = @"COPersistentRootChangeCount";
NSString *kCOPersistentRootDeleted = @"COPersistentRootDeleted";
NSString *kCOStoreUUID = @"COStoreUUID";
NSString *kCOStoreURL = @"COStoreURL";
