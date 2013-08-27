#import "COSQLiteStorePersistentRootBackingStore.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
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
    ASSIGN(_uuid, aUUID);
    
    if (_shareDB)
    {
        ASSIGN(db_, [store database]);
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
            [self release];
            return nil;
        }
        
        // Use write-ahead-log mode
        {
            NSString *result = [db_ stringForQuery: @"PRAGMA journal_mode=WAL"];
            
            if ([@"wal" isEqualToString: result])
            {
                // See comments in COSQiteStore
                [db_ executeUpdate: @"PRAGMA synchronous=NORMAL"];
            }
            else
            {
                NSLog(@"Enabling WAL mode failed.");
            }
        }
    }
    
    [db_ executeUpdate: [NSString stringWithFormat:
                         @"CREATE TABLE IF NOT EXISTS %@ (revid INTEGER PRIMARY KEY ASC, "
                         "contents BLOB, metadata BLOB, timestamp REAL, parent INTEGER, root BLOB, deltabase INTEGER, "
                         "bytesInDeltaRun INTEGER, garbage BOOLEAN)", [self tableName]]];
    
    if ([db_ hadError])
    {
		NSLog(@"Error %d: %@", [db_ lastErrorCode], [db_ lastErrorMessage]);
        [self release];
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

- (void)dealloc
{
    [_uuid release];
	[db_ release];
	[super dealloc];
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

- (CORevisionInfo *) revisionForID: (CORevisionID *)aToken
{
    CORevisionInfo *result = nil;
    FMResultSet *rs = [db_ executeQuery:
                       [NSString stringWithFormat: @"SELECT parent, metadata, timestamp FROM %@ WHERE revid = ?", [self tableName]],
                       [NSNumber numberWithLongLong: [aToken revisionIndex]]];
	if ([rs next])
	{
        int64_t parent = [rs longLongIntForColumnIndex: 0];
        
        NSDictionary *metadata = nil;
        NSData *data = [rs dataForColumnIndex: 1];
        if (data != nil)
        {
            metadata = [NSJSONSerialization JSONObjectWithData: data
                                                       options: 0
                                                         error: NULL];
        }
        
        CORevisionID *parentId = parent != -1 ? [aToken revisionIDWithRevisionIndex: parent] : nil;
        
        result = [[[CORevisionInfo alloc] init] autorelease];
        result.revisionID = aToken;
        result.parentRevisionID = parentId;
        result.metadata = metadata;
        result.date = [rs dateForColumnIndex: 2];
	}
    [rs close];
    
	return result;
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
    NSParameterAssert(baseRevid < revid);
    
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
        [item release];
    }
    
    COItemGraph *result = [[[COItemGraph alloc] initWithItemForUUID: resultDict
                                                                   rootItemUUID: root] autorelease];
    return result;
}

- (COItemGraph *) partialItemGraphFromRevid: (int64_t)baseRevid toRevid: (int64_t)revid
{
    return [self partialItemGraphFromRevid: baseRevid toRevid: revid restrictToItemUUIDs: nil];
}

- (COItemGraph *) itemGraphForRevid: (int64_t)revid
{
    COItemGraph *result = [self partialItemGraphFromRevid: -1 toRevid: revid restrictToItemUUIDs: nil];

    // TODO: For debugging only, remove
    if (result != nil)
    {
        COValidateItemGraph(result);
    }
    
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
- (int64_t) writeItemGraph: (id<COItemGraph>)anItemTree
              withMetadata: (NSDictionary *)metadata
                withParent: (int64_t)aParent
             modifiedItems: (NSArray*)modifiedItems
                     error: (NSError **)error
{
    // TODO: For debugging only, remove
    COValidateItemGraph(anItemTree);
    
    BOOL inTransaction = [db_ inTransaction];
    if (!inTransaction)
    {
        if (![db_ beginTransaction])
        {
            return -1;
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
        if (modifiedItems == nil)
        {
            modifiedItems = [anItemTree itemUUIDs];
        }
        contentsBlob = contentsBLOBWithItemTree(anItemTree, modifiedItems);
        bytesInDeltaRun = lastBytesInDeltaRun + [contentsBlob length];
    }
    else
    {
        deltabase = rowid;
        contentsBlob = contentsBLOBWithItemTree(anItemTree, [anItemTree itemUUIDs]);
        bytesInDeltaRun = [contentsBlob length];
    }

    NSData *metadataBlob = nil;
    if (metadata != nil)
    {
        metadataBlob = [NSJSONSerialization dataWithJSONObject: metadata options: 0 error: NULL];
    }
    
    BOOL ok = [db_ executeUpdate: [NSString stringWithFormat: @"INSERT INTO %@ (revid, "
        "contents, metadata, timestamp, parent, root, deltabase, "
        "bytesInDeltaRun, garbage) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)", [self tableName]],
        [NSNumber numberWithLongLong: rowid],
        contentsBlob,
        metadataBlob,
        [NSDate date],
        [NSNumber numberWithLongLong: aParent],
        [[anItemTree rootItemUUID] dataValue],
        [NSNumber numberWithLongLong: deltabase],
        [NSNumber numberWithLongLong: bytesInDeltaRun]];
    
    if (!inTransaction)
    {
        ok = ok && [db_ commit];
    }
    
    if (!ok)
    {
        return -1;
    }
    
    return rowid;
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

@end
