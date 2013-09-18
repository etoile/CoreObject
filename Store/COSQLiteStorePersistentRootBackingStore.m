#import "COSQLiteStorePersistentRootBackingStore.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
#import <EtoileFoundation/ETCollection.h>
#import "COItemGraph.h"
#import "COItem.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "COSQLiteStorePersistentRootBackingStoreBinaryFormats.h"
#import "COItem+Binary.h"
#import "CORevisionInfo.h"
#import "CORevisionID.h"
#import "COSQLiteStore.h"

@interface COSQLiteStore (Private)

- (FMDatabase *) database;

@end

@implementation COSQLiteStorePersistentRootBackingStore

- (NSString *) tableName
{
    if (_shareDB)
    {
        return [NSString stringWithFormat: @"`commits-%@`", _uuid];
    }
    else
    {
        return @"commits";
    }
}

- (id)initWithPersistentRootUUID: (ETUUID*)aUUID
                           store: (COSQLiteStore *)store
                      useStoreDB: (BOOL)share
                           error: (NSError **)error
{
    SUPERINIT;
    
    _shareDB = share;
    _store = store;
    _uuid =  aUUID;
    
    if (_shareDB)
    {
        db_ =  [store database];
    }
    else
    {
        NSString *path = [[[store URL] path] stringByAppendingPathComponent: [NSString stringWithFormat: @"%@.sqlite", _uuid]];
        NILARG_EXCEPTION_TEST(path);
        
        db_ = [[FMDatabase alloc] initWithPath: path];
        
        [db_ setShouldCacheStatements: YES];
        
        if (![db_ open])
        {
            NSLog(@"Error %d: %@", [db_ lastErrorCode], [db_ lastErrorMessage]);
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
    }
    
    [db_ executeUpdate: [NSString stringWithFormat:
                         @"CREATE TABLE IF NOT EXISTS %@ (revid INTEGER PRIMARY KEY ASC, "
                         "contents BLOB, metadata BLOB, timestamp REAL, parent INTEGER, mergeparent INTEGER, branchuuid BLOB, root BLOB, deltabase INTEGER, "
                         "bytesInDeltaRun INTEGER, garbage BOOLEAN, uuid BLOB)", [self tableName]]];

    [db_ executeUpdate: [NSString stringWithFormat:
                         @"CREATE INDEX IF NOT EXISTS %@ ON %@ (uuid)", [[self tableName] stringByAppendingString: @"_uuid"], [self tableName]]];
    
    if ([db_ hadError])
    {
		NSLog(@"Error %d: %@", [db_ lastErrorCode], [db_ lastErrorMessage]);
		return nil;
	}

	return self;
}

- (BOOL)close
{
    if (!_shareDB)
    {
        return [db_ close];
    }
    else
    {
        return YES;
    }
}


- (BOOL) beginTransaction
{
    return [db_ beginTransaction];
}
- (BOOL) commit
{
    return [db_ commit];
}

/* DB Setup */


/*
 
 commits
 =======
 
 revid INTEGER PRIMARY KEY | contents BLOB | metadata BLOB | parent INTEGER | root BLOB | deltabase INTEGER
 --------------------------+---------------+---------------+----------------+-----------+------------------
 0                         | ???           | ???           | null           | xxxxxxxxx | 0
 1                         | ???           | ???           | 0              | xxxxxxxxx | 0
 2                         | ???           | ???           | 1              | xxxxxxxxx | 2
 3                         | ???           | ???           | 2              | xxxxxxxxx | 2
 4                         | ???           | ???           | 3              | xxxxxxxxx | 2
 5                         | ???           | ???           | 2              | xxxxxxxxx | 2
 6                         | ???           | ???           | 0              | xxxxxxxxx | 6
 
 
 
 suppose we want to reconstruct the delta revision 500000:
 
 SELECT * FROM test WHERE revid <= 500000 AND revid >= (SELECT MAX(revid) FROM test WHERE delta = 0 AND revid < 500000);

 */

- (CORevisionID *) revisionIDForRevid: (int64_t)aRevid
{
    NSData *revUUID = [db_ dataForQuery:
                          [NSString stringWithFormat: @"SELECT uuid FROM %@ WHERE revid = ?", [self tableName]],
                          [NSNumber numberWithLongLong: aRevid]];
    
    if (revUUID != nil)
    {
        return [CORevisionID revisionWithPersistentRootUUID: _uuid
                                            revisionUUID: [ETUUID UUIDWithData: revUUID]];
    }
    else
    {
        return nil;
    }
}

- (CORevisionInfo *) revisionForID: (CORevisionID *)aToken
{
    CORevisionInfo *result = nil;
    FMResultSet *rs = [db_ executeQuery:
                       [NSString stringWithFormat: @"SELECT parent, mergeparent, branchuuid, metadata, timestamp FROM %@ WHERE uuid = ?", [self tableName]],
                       [[aToken revisionUUID] dataValue]];
	if ([rs next])
	{
        // N.B.: Watch for null being returned as 0
        int64_t parent = [rs longLongIntForColumnIndex: 0];
        int64_t mergeparent = [rs longLongIntForColumnIndex: 1];
        NSDictionary *metadata = nil;
        NSData *data = [rs dataForColumnIndex: 3];
        if (data != nil)
        {
            metadata = [NSJSONSerialization JSONObjectWithData: data
                                                       options: 0
                                                         error: NULL];
        }
        
        result = [[CORevisionInfo alloc] init];
        result.revisionID = aToken;
        result.parentRevisionID = [self revisionIDForRevid: parent];
        result.mergeParentRevisionID = [self revisionIDForRevid: mergeparent];
		result.branchUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
        result.metadata = metadata;
        result.date = [rs dateForColumnIndex: 4];
	}
    [rs close];
    
	return result;
}

- (int64_t) revidForUUID: (ETUUID *)aUUID
{
    NSNumber *revid = [db_ numberForQuery:
                       [NSString stringWithFormat: @"SELECT revid FROM %@ WHERE uuid = ?", [self tableName]], [aUUID dataValue]];
    if (revid == nil)
    {
        return -1;
    }
    return [revid longLongValue];
}

- (int64_t) revidForRevisionID: (CORevisionID *)aToken
{
    return [self revidForUUID: [aToken revisionUUID]];
}

- (ETUUID *) rootUUIDForRevid: (int64_t)revid
{
    ETUUID *result = nil;
    FMResultSet *rs = [db_ executeQuery: [NSString stringWithFormat: @"SELECT root FROM %@ WHERE revid = ?", [self tableName]],
                       [NSNumber numberWithLongLong: revid]];
	if ([rs next])
	{
        result = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
	}
    [rs close];
    
	return result;
}

- (BOOL) hasRevid: (int64_t)revid
{
    return [db_ boolForQuery: [NSString stringWithFormat: @"SELECT 1 FROM %@ WHERE revid = ?", [self tableName]],
            [NSNumber numberWithLongLong: revid]];
}

/**
 * Returns the item tree 
 */
- (COItemGraph *) partialItemGraphFromRevid: (int64_t)baseRevid
                                    toRevid: (int64_t)revid
                        restrictToItemUUIDs: (NSSet *)itemSet
{
    NSNumber *revidObj = [NSNumber numberWithLongLong: revid];
    
    NSMutableDictionary *dataForUUID = [NSMutableDictionary dictionary];
    
    FMResultSet *rs = [db_ executeQuery: [NSString stringWithFormat:
                                          @"SELECT revid, contents, parent, deltabase "
                                          "FROM %@ "
                                          "WHERE revid <= ? AND revid >= (SELECT deltabase FROM %@ WHERE revid = ?) "
                                          "ORDER BY revid DESC", [self tableName], [self tableName]],
                                        revidObj, revidObj];
    
    int64_t nextRevId = -1;
  
    BOOL wasEmpty = YES;    
    while ([rs next])
    {
        wasEmpty = NO;
        
        const int64_t revid = [rs longLongIntForColumnIndex: 0];
        NSData *contentsData = [rs dataForColumnIndex: 1];
        const int64_t parent = [rs longLongIntForColumnIndex: 2];
        const int64_t deltabase = [rs boolForColumnIndex: 3];
        
        if (revid == nextRevId || nextRevId == -1)
        {
            ParseCombinedCommitDataInToUUIDToItemDataDictionary(dataForUUID, contentsData, NO, itemSet);
            
            // TODO: If we are filtering to a known set of items, we can break out once we have all of them.
            
            if (parent == baseRevid)
            {
                // The caller _already_ has the state of baseRevid. If the state we just processed's
                // parent is baseRevid, we can stop because we have everything already.
                break;
            }
            
            nextRevId = parent;
            
            // validity check            
            assert([rs hasAnotherRow] || deltabase == revid);
        }
        else
        {
            // validity check
            assert([rs hasAnotherRow]);
        }
    }
	
    [rs close];
    
    if (wasEmpty)
    {
        return nil;
    }
    
    ETUUID *root = [self rootUUIDForRevid: revid];
    
    // Convert dataForUUID to a UUID -> COItem mapping.
    // TODO: Eliminate this by giving COItem to be created with a serialized NSData of itself,
    // and lazily deserializing itself.
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
    for (ETUUID *uuid in dataForUUID)
    {        
        NSData *data = [dataForUUID objectForKey: uuid];
        COItem *item = [[COItem alloc] initWithData: data];
        [resultDict setObject: item
                       forKey: uuid];
    }
    
    COItemGraph *result = [[COItemGraph alloc] initWithItemForUUID: resultDict
                                                                   rootItemUUID: root];
    return result;
}

- (COItemGraph *) partialItemGraphFromRevid: (int64_t)baseRevid toRevid: (int64_t)revid
{
    return [self partialItemGraphFromRevid: baseRevid toRevid: revid restrictToItemUUIDs: nil];
}

- (COItemGraph *) itemGraphForRevid: (int64_t)revid
{
    COItemGraph *result = [self partialItemGraphFromRevid: -1 toRevid: revid restrictToItemUUIDs: nil];

#ifdef DEBUG
    if (result != nil)
    {
        COValidateItemGraph(result);
    }
#endif
    
    return result;
}

- (COItemGraph *) itemGraphForRevid: (int64_t)revid restrictToItemUUIDs: (NSSet *)itemSet
{
    return [self partialItemGraphFromRevid: -1 toRevid: revid restrictToItemUUIDs: itemSet];
}


static NSData *contentsBLOBWithItemTree(id<COItemGraph> anItemTree, NSArray *modifiedItems)
{
    NSMutableData *result = [NSMutableData dataWithCapacity: 64536];
    
    for (ETUUID *uuid in modifiedItems)
    {
        COItem *item = [anItemTree itemForUUID: uuid];
        NSData *itemJson = [item dataValue];
        
        AddCommitUUIDAndDataToCombinedCommitData(result, uuid, itemJson);
    }
    
    return result;
}

- (int64_t) nextRowid
{
    int64_t result = 0;
    FMResultSet *rs = [db_ executeQuery: [NSString stringWithFormat: @"SELECT MAX(rowid) FROM %@", [self tableName]]];
	if ([rs next])
	{
        if (![rs columnIndexIsNull: 0])
        {
            result = [rs longLongIntForColumnIndex: 0] + 1;
        }
	}
    [rs close];
    
	return result;
}

- (int64_t) deltabaseForRowid: (int64_t)aRowid
{
    int64_t deltabase = -1;
    
    FMResultSet *rs = [db_ executeQuery: [NSString stringWithFormat: @"SELECT deltabase FROM %@ WHERE rowid = ?", [self tableName]],
                       [NSNumber numberWithLongLong: aRowid]];
    if ([rs next])
    {
        deltabase = [rs longLongIntForColumnIndex: 0];
    }
    [rs close];

    return deltabase;
}

- (int64_t) bytesInDeltaRunForRowid: (int64_t)aRowid
{
    int64_t bytesInDeltaRun = 0;
    
    FMResultSet *rs = [db_ executeQuery: [NSString stringWithFormat: @"SELECT bytesInDeltaRun FROM %@ WHERE rowid = ?", [self tableName]],
                       [NSNumber numberWithLongLong: aRowid]];
    if ([rs next])
    {
        bytesInDeltaRun = [rs longLongIntForColumnIndex: 0];
    }
    [rs close];
    
    return bytesInDeltaRun;
}

/**
 * @param aParent -1 for no parent, otherwise the parent of this commit
 * @param modifiedItems nil for all items in anItemTree, otherwise a subset
 */
- (CORevisionID *) writeItemGraph: (COItemGraph*)anItemTree
                     revisionUUID: (ETUUID *)aRevisionUUID
                     withMetadata: (NSDictionary *)metadata
                       withParent: (int64_t)aParent
                  withMergeParent: (int64_t)aMergeParent
                       branchUUID: (ETUUID *)aBranchUUID
                            error: (NSError **)error
{
#ifdef DEBUG
    COValidateItemGraph(anItemTree);
#endif

    NSParameterAssert(aParent >= -1);
    NSParameterAssert(aMergeParent >= -1);
    NSParameterAssert(aRevisionUUID != nil);
    
    BOOL inTransaction = [db_ inTransaction];
    if (!inTransaction)
    {
        if (![db_ beginTransaction])
        {
            return nil;
        }
    }
    
    const int64_t parent_deltabase = [self deltabaseForRowid: aParent];
    const int64_t rowid = [self nextRowid];
    const int64_t lastBytesInDeltaRun = [self bytesInDeltaRunForRowid: rowid - 1];
    int64_t deltabase;
    NSData *contentsBlob;
    int64_t bytesInDeltaRun;
    
    // Limit delta runs to 9 commits:
    const BOOL delta = (parent_deltabase != -1 && rowid - parent_deltabase < 50);
    
    // Limit delta runs to 4k
    //const BOOL delta = (parent_deltabase != -1 && lastBytesInDeltaRun < 4096);
    if (delta)
    {
        deltabase = parent_deltabase;
        contentsBlob = contentsBLOBWithItemTree(anItemTree, [anItemTree itemUUIDs]);
        bytesInDeltaRun = lastBytesInDeltaRun + [contentsBlob length];
    }
    else
    {
        deltabase = rowid;
        
        // Load the parent into memory, merge the provided items with the parent's.
        //
        // Previous iterations of COSQLiteStore required the caller to always
        // provide the full item tree, and so we didn't need to do this
        
        COItemGraph *parentGraph = [self itemGraphForRevid: aParent];
        COItemGraph *combinedGraph;
        
        if (parentGraph != nil)
        {
            combinedGraph = parentGraph;
            [combinedGraph addItemGraph: anItemTree];
        }
        else
        {
            combinedGraph = anItemTree;
        }
        
        contentsBlob = contentsBLOBWithItemTree(combinedGraph, [combinedGraph itemUUIDs]);
        bytesInDeltaRun = [contentsBlob length];
    }

    NSData *metadataBlob = nil;
    if (metadata != nil)
    {
        metadataBlob = [NSJSONSerialization dataWithJSONObject: metadata options: 0 error: NULL];
    }
    
    BOOL ok = [db_ executeUpdate: [NSString stringWithFormat: @"INSERT INTO %@ (revid, "
        "contents, metadata, timestamp, parent, mergeparent, root, branchuuid, deltabase, "
        "bytesInDeltaRun, garbage, uuid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)", [self tableName]],
        [NSNumber numberWithLongLong: rowid],
        contentsBlob,
        metadataBlob,
        [NSDate date],
        [NSNumber numberWithLongLong: aParent],
        [NSNumber numberWithLongLong: aMergeParent],
        [[anItemTree rootItemUUID] dataValue],
		[aBranchUUID dataValue],
        [NSNumber numberWithLongLong: deltabase],
        [NSNumber numberWithLongLong: bytesInDeltaRun],
        [aRevisionUUID dataValue]];
    
    if (!inTransaction)
    {
        ok = ok && [db_ commit];
    }
    
    if (!ok)
    {
        return nil;
    }
    
    CORevisionID *revidObject = [CORevisionID revisionWithPersistentRootUUID: _uuid
                                                             revisionUUID: aRevisionUUID];

    return revidObject;
}

- (NSIndexSet *) revidsFromRevid: (int64_t)baseRevid toRevid: (int64_t)revid
{
    NSParameterAssert(baseRevid <= revid);
    
    NSMutableIndexSet *result = [NSMutableIndexSet indexSet];

    FMResultSet *rs = [db_ executeQuery: [NSString stringWithFormat:
                                          @"SELECT revid, parent "
                                          "FROM %@ "
                                          "WHERE revid <= ? AND revid >= ? "
                                          "ORDER BY revid DESC", [self tableName]],
                        [NSNumber numberWithLongLong: revid],
                        [NSNumber numberWithLongLong: baseRevid]];
    
    int64_t nextRevId = revid;
    
    while ([rs next])
    {
        const int64_t current = [rs longLongIntForColumnIndex: 0];
        const int64_t parent = [rs longLongIntForColumnIndex: 1];
        
        if (current == nextRevId)
        {
            [result addIndex: current];
            
            nextRevId = parent;
            
            // validity check
            assert([rs hasAnotherRow] || baseRevid == current);
        }
        else
        {
            // validity check
            assert([rs hasAnotherRow]);
        }
    }
	
    [rs close];

    if (![result containsIndex: baseRevid]
        || ![result containsIndex: revid])
    {
        NSLog(@"Warning, -revidsFromRevid:toRevid: given invalid arguments");
        return nil;
    }
    
    return result;
}

- (BOOL) deleteRevids: (NSIndexSet *)revids
{
    BOOL inTransaction = [db_ inTransaction];
    if (!inTransaction)
    {
        [db_ beginTransaction];
    }
    
    for (NSUInteger i = [revids firstIndex]; i != NSNotFound; i = [revids indexGreaterThanIndex: i])
    {
        [db_ executeUpdate: [NSString stringWithFormat: @"UPDATE %@ SET garbage = 1 WHERE revid = ?", [self tableName]],
            [NSNumber numberWithUnsignedInteger: i]];
    }

    // Debugging:
//    NSLog(@"In response to delete %@", revids);
//    FMResultSet *rs = [db_ executeQuery: @"SELECT revid, deltabase FROM commits WHERE deltabase IN (SELECT deltabase FROM commits GROUP BY deltabase HAVING garbage = 1)"];
//    while ([rs next])
//    {
//        NSLog(@"Deleting %d (db: %d)", [rs intForColumnIndex:0], [rs intForColumnIndex: 1]);
//    }
//    [rs close];
    
    // For each delta base, delete the contiguous range of garbage revids starting at the maximum
    // and extending down to the first non-garbage revid
    
    // Example which can be pasted in the sqlite3 prompt to experiment with this query:
    
    /*
     
     drop table c;
     create table c (revid integer, deltabase integer, garbage boolean);
     
     insert into c values(0,0,0);
     insert into c values(1,0,1); -- marked as garbage, will be selected for deletion
     
     insert into c values(2,2,1); -- marked as garbage, will be selected for deletion
     insert into c values(3,2,1); -- marked as garbage, will be selected for deletion
     
     insert into c values(4,4,0);
     insert into c values(5,4,0);
     
     insert into c values(6,6,0);
     insert into c values(7,6,1); -- marked as garbage, won't be deleted because there are higher non-garbage revids in this delta run
     insert into c values(8,6,0);
     
     SELECT commits.revid
     FROM c AS commits
     LEFT OUTER JOIN (SELECT deltabase, MAX(revid) AS maxkeptrevid FROM c WHERE garbage = 0 GROUP BY deltabase) AS info
     USING (deltabase)
     WHERE (commits.revid > info.maxkeptrevid) OR info.maxkeptrevid IS NULL;
     
     -- The "OR info.maxkeptrevid IS NULL" part is so that we delete all commits in delta runs where all commits are garbage.
     
     */
    
    // Could be done at a later time
    [db_ executeUpdate: [NSString stringWithFormat: @"DELETE FROM %@ WHERE revid IN (SELECT commits.revid "
                         "FROM %@ AS commits "
                         "LEFT OUTER JOIN (SELECT deltabase, MAX(revid) AS maxkeptrevid FROM %@ WHERE garbage = 0 GROUP BY deltabase) AS info "
                         "USING (deltabase) "
                         "WHERE (commits.revid > info.maxkeptrevid) OR info.maxkeptrevid IS NULL)",
                         [self tableName], [self tableName], [self tableName]]];
    
    // TODO: Vacuum here?
    
    if (!inTransaction)
    {
        [db_ commit];
    }
    
    return ![db_ hadError];
}

- (NSIndexSet *) revidsUsedRange
{
    NSNumber *max = [db_ numberForQuery: [NSString stringWithFormat: @"SELECT MAX(rowid) FROM %@", [self tableName]]];
    if (max != nil)
    {
        return [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [max longLongValue] + 1)];
    }
    return nil;
}

- (CORevisionInfo *)revisionInfoWithResultSet: (FMResultSet *)rs revisionIDs: (NSMutableDictionary *)revIDs
{
	ETUUID *uuid = [ETUUID UUIDWithData: [rs dataForColumn: @"uuid"]];
	// N.B.: Watch for null being returned as 0
	int64_t parent = [rs longLongIntForColumn: @"parent"];
	int64_t mergeparent = [rs longLongIntForColumn: @"mergeParent"];
	NSData *data = [rs dataForColumn: @"metadata"];
	NSDictionary *metadata = nil;

	if (data != nil)
	{
		// TODO: Handle error
		NSError *error = nil;
		metadata = [NSJSONSerialization JSONObjectWithData: data
												   options: 0
													 error: &error];
		ETAssert(error == nil);
	}
	
	CORevisionInfo *rev = [CORevisionInfo new];

	[rev setRevisionID: [CORevisionID revisionWithPersistentRootUUID: _uuid revisionUUID: uuid]];
	[rev setParentRevisionID: (id)[NSNumber numberWithLongLong: parent]];
	[rev setMergeParentRevisionID: (id)[NSNumber numberWithLongLong: mergeparent]];
	[rev setBranchUUID: [ETUUID UUIDWithData: [rs dataForColumn: @"branchUUID"]]];
	[rev setMetadata: metadata];
	[rev setDate: [rs dateForColumn: @"timestamp"]];

	int64_t revid = [rs longLongIntForColumn: @"revid"];

	/* Memorize the revision ID to support resolving parent and merge parent 
	   revision IDs once revIDs contains all the revisions */

	[revIDs setObject: [rev revisionID]
			   forKey: [NSNumber numberWithLongLong: revid]];

	 return rev;
}

- (void)resolveRevisionIDsInRevisionsInfos: (NSArray *)revInfos
                          usingRevisionIDs: (NSDictionary *)revIDs
{
	for (CORevisionInfo *revInfo in revInfos)
	{
		[revInfo setParentRevisionID: [revIDs objectForKey: [revInfo parentRevisionID]]];
		[revInfo setMergeParentRevisionID: [revIDs objectForKey: [revInfo mergeParentRevisionID]]];

		ETAssert([revInfo parentRevisionID] != nil || [revInfo isEqual: [revInfos firstObject]]);
	}
}

- (NSArray *)revisionInfosForBranchUUID: (ETUUID *)aBranchUUID
                       headRevisionUUID: (ETUUID *)aHeadRevUUID
                                options: (COBranchRevisionReadingOptions)options
{
	NILARG_EXCEPTION_TEST(aBranchUUID);

	int64_t headRevid = [self revidForUUID: aHeadRevUUID];
	FMResultSet *rs = [db_ executeQuery: [NSString stringWithFormat:
		@"SELECT revid, parent, branchuuid, metadata, timestamp, mergeparent, uuid "
		 "FROM %@ WHERE revid BETWEEN 0 AND ? ORDER BY revid DESC",
		[self tableName]], [NSNumber numberWithLongLong: headRevid]];

	NSUInteger suggestedMaxRevCount = 50000;
	NSMutableArray *revInfos = [NSMutableArray arrayWithCapacity: suggestedMaxRevCount];
	NSMutableDictionary *revIDs = [NSMutableDictionary dictionaryWithCapacity: suggestedMaxRevCount];
	/* Represents a branch in the path leading to the end branch, while 
	   navigating the history backwards to collect branch revisions. */
	NSData *visitedBranchUUIDData = [aBranchUUID dataValue];
	int64_t parentRevid = -1;
	BOOL isFirstResult = YES;

	while ([rs next])
	{
		NSData *branchUUIDData = [rs dataForColumnIndex: 2];
		BOOL isValidBranch = ([branchUUIDData isEqualToData: visitedBranchUUIDData]);
		int64_t revid = [rs longLongIntForColumnIndex: 0];
		BOOL isParentRev = (revid == parentRevid);
		BOOL skippingUnrelatedBranchRevisions = (isValidBranch == NO && isParentRev == NO);
		
		if (skippingUnrelatedBranchRevisions)
			continue;
	
		if (isValidBranch == NO && (options & COBranchRevisionReadingParentBranches) == NO)
			break;

		if (isFirstResult || isParentRev || (options & COBranchRevisionReadingDivergentRevisions))
		{
			[revInfos insertObject: [self revisionInfoWithResultSet: rs revisionIDs: revIDs]
			               atIndex: 0];
			parentRevid = [rs longLongIntForColumnIndex: 1];
			visitedBranchUUIDData = branchUUIDData;
		}

		isFirstResult = NO;
    }
	[rs close];

	[self resolveRevisionIDsInRevisionsInfos: revInfos
							usingRevisionIDs: revIDs];

	return revInfos;
}

@end
