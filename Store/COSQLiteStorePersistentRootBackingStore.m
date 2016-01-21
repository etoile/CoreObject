/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  November 2012
    License:  MIT  (see COPYING)
 */

#import "COSQLiteStorePersistentRootBackingStore.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
#import <EtoileFoundation/ETCollection.h>
#import <EtoileFoundation/ETCollection+HOM.h>
#import <EtoileFoundation/NSArray+Etoile.h>
#import "COItemGraph.h"
#import "COItem.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "COSQLiteStorePersistentRootBackingStoreBinaryFormats.h"
#import "COItem+Binary.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"
#import "COSQLiteStore+Private.h"
#import "CODateSerialization.h"
#import "COJSONSerialization.h"
#ifdef GNUSTEP
#	include <openssl/sha.h>
#else
#	include <CommonCrypto/CommonDigest.h>
#	define SHA1 CC_SHA1
#endif

/**
 * Validate item graphs on save/load.
 * (e.g., ensures no broken references).
 *
 * This will dramaticaly slow down saving from O(size of delta to write) to
 * O(size of full state).
 */
//#define VALIDATE_ITEM_GRAPHS 1

@interface COSQLiteStore (Private)

- (FMDatabase *) database;

@end

@implementation COSQLiteStorePersistentRootBackingStore

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
	
	[self beginTransaction];
	
	// N.B. UNIQUE constraint on uuid gives it an index automatically.
    [db_ executeUpdate: @"CREATE TABLE IF NOT EXISTS commits (revid INTEGER PRIMARY KEY ASC, backinguuid BLOB NOT NULL, "
                         "contents BLOB, hash BLOB, metadata BLOB, timestamp INTEGER, parent INTEGER, mergeparent INTEGER, branchuuid BLOB, persistentrootuuid BLOB, deltabase INTEGER, "
                         "bytesInDeltaRun INTEGER, garbage BOOLEAN, uuid BLOB NOT NULL UNIQUE)"];

	[db_ executeUpdate:  @"CREATE TABLE IF NOT EXISTS backingmetadata (backinguuid BLOB PRIMARY KEY, root BLOB NOT NULL CHECK (length(root) = 16))"];
	
        [db_ executeUpdate: @"CREATE INDEX IF NOT EXISTS commits_backinguuid_index ON commits(backinguuid)"];
    
	[self commit];
	
	// FIXME: -hadError only looks at the success of the last statement.
    if ([db_ hadError])
    {
		NSLog(@"Error %d: %@", [db_ lastErrorCode], [db_ lastErrorMessage]);
		return nil;
	}

	return self;
}

- (void) clearBackingStore
{
	[self beginTransaction];
	[db_ executeUpdate: @"DELETE FROM commits WHERE backinguuid = ?", [_uuid dataValue]];
	[db_ executeUpdate: @"DELETE FROM backingmetadata WHERE backinguuid = ?", [_uuid dataValue]];
	ETAssert([self commit]);
}

- (ETUUID *) UUID
{
	return _uuid;
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
    return [db_ savepoint: @"backingStore"];
}
- (BOOL) commit
{
    return [db_ releaseSavepoint: @"backingStore"];
}
- (BOOL) rollback
{
    return [db_ rollbackToSavepoint: @"backingStore"];
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

- (ETUUID *) revisionUUIDForRevid: (int64_t)aRevid
{
    NSData *revUUID = [db_ dataForQuery: @"SELECT uuid FROM commits WHERE revid = ?", [NSNumber numberWithLongLong: aRevid]];
    
    if (revUUID != nil)
    {
        return [ETUUID UUIDWithData: revUUID];
    }
    else
    {
        return nil;
    }
}

- (CORevisionInfo *) revisionInfoForRevisionUUID: (ETUUID *)aRevisionUUID
{
    CORevisionInfo *result = nil;
    FMResultSet *rs = [db_ executeQuery: @"SELECT parent, mergeparent, branchuuid, persistentrootuuid, metadata, timestamp FROM commits WHERE uuid = ?",
                       [aRevisionUUID dataValue]];
	if ([rs next])
	{
        // N.B.: Watch for null being returned as 0
        int64_t parent = [rs longLongIntForColumnIndex: 0];
        int64_t mergeparent = [rs longLongIntForColumnIndex: 1];
        
        result = [[CORevisionInfo alloc] init];
        result.revisionUUID = aRevisionUUID;
        result.parentRevisionUUID = [self revisionUUIDForRevid: parent];
        result.mergeParentRevisionUUID = [self revisionUUIDForRevid: mergeparent];
		result.branchUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 2]];
		result.persistentRootUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 3]];
        NSData *data = [rs dataForColumnIndex: 4];
        if (data != nil)
        {
            result.metadata = COJSONObjectWithData(data, NULL);
        }
        result.date = CODateFromJavaTimestamp([rs numberForColumnIndex: 5]);
	}
    [rs close];
    
	return result;
}

- (int64_t) revidForUUID: (ETUUID *)aUUID
{
    NSNumber *revid = [db_ numberForQuery: @"SELECT revid FROM commits WHERE uuid = ?", [aUUID dataValue]];
    if (revid == nil)
    {
        return -1;
    }
    return [revid longLongValue];
}

- (NSIndexSet *)revidsForUUIDs: (NSArray *)UUIDs
{
	NSMutableIndexSet *revids = [NSMutableIndexSet new];

        for (ETUUID *uuid in UUIDs)
        {
            FMResultSet *rs = [db_ executeQuery: @"SELECT revid FROM commits WHERE uuid = ?", [uuid dataValue]];
            if ([rs next])
            {
                [revids addIndex: [rs int64ForColumnIndex: 0]];
            }
            [rs close];
        }
	
	return revids;
}

- (ETUUID *) rootUUID
{
	if (_rootObjectUUID == nil)
	{
		FMResultSet *rs = [db_ executeQuery: @"SELECT root FROM backingmetadata WHERE backinguuid = ?", [_uuid dataValue]];
		if ([rs next])
		{
			_rootObjectUUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
		}
		[rs close];
    }
	return _rootObjectUUID;
}


- (BOOL) hasRevid: (int64_t)revid
{
    return [db_ boolForQuery: @"SELECT 1 FROM commits WHERE revid = ? AND backinguuid = ?",
            [NSNumber numberWithLongLong: revid],
            [_uuid dataValue]];
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
    
    FMResultSet *rs = [db_ executeQuery:  @"SELECT revid, contents, hash, parent, deltabase "
                                          "FROM commits "
                                          "WHERE revid <= ? AND revid >= (SELECT deltabase FROM commits WHERE revid = ?) AND backinguuid = ? "
                                          "ORDER BY revid DESC",
                                        revidObj, revidObj, [_uuid dataValue]];
    
    int64_t nextRevId = -1;
  
    BOOL wasEmpty = YES;    
    while ([rs next])
    {
        wasEmpty = NO;
        
        const int64_t revid = [rs longLongIntForColumnIndex: 0];
        NSData *contentsData = [rs dataForColumnIndex: 1];
		NSData *hashData = [rs dataForColumnIndex: 2];
        const int64_t parent = [rs longLongIntForColumnIndex: 3];
        const int64_t deltabase = [rs boolForColumnIndex: 4];
        
        if (revid == nextRevId || nextRevId == -1)
        {
			NSData *actualHash = Sha1Data(contentsData);
			ETAssert([hashData isEqual: actualHash]);
			
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
    
    ETUUID *root = [self rootUUID];
    
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

#ifdef VALIDATE_ITEM_GRAPHS
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


NSData *contentsBLOBWithItemTree(id<COItemGraph> itemGraph)
{
    NSMutableData *result = [NSMutableData dataWithCapacity: 64536];
    
	NSArray *sortedUUIDs = [[itemGraph itemUUIDs] sortedArrayUsingComparator: ^(id obj1, id obj2){
		ETUUID *uuid1 = (ETUUID *)obj1;
		ETUUID *uuid2 = (ETUUID *)obj2;
		int result = memcmp([uuid1 UUIDValue], [uuid2 UUIDValue], 16);
		return (result < 0)
			? NSOrderedAscending
			: ((result == 0)
			   ? NSOrderedSame
			   : NSOrderedDescending);
	}];
	
    for (ETUUID *uuid in sortedUUIDs)
    {
        COItem *item = [itemGraph itemForUUID: uuid];
        NSData *itemData = [item dataValue];
        
        AddCommitUUIDAndDataToCombinedCommitData(result, uuid, itemData);
    }
    
    return result;
}

- (int64_t) nextRowid
{
    int64_t result = 0;
    FMResultSet *rs = [db_ executeQuery: @"SELECT MAX(rowid) FROM commits"];
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
    
    FMResultSet *rs = [db_ executeQuery: @"SELECT deltabase FROM commits WHERE rowid = ?",
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
    
    FMResultSet *rs = [db_ executeQuery: @"SELECT bytesInDeltaRun FROM commits WHERE rowid = ?",
                       [NSNumber numberWithLongLong: aRowid]];
    if ([rs next])
    {
        bytesInDeltaRun = [rs longLongIntForColumnIndex: 0];
    }
    [rs close];
    
    return bytesInDeltaRun;
}

static NSData *Sha1Data(NSData *data)
{
	unsigned char buffer[20];
	SHA1([data bytes], [data length], buffer);
	return [NSData dataWithBytes: buffer length: 20];
}

/**
 * @param aParent -1 for no parent, otherwise the parent of this commit
 * @param modifiedItems nil for all items in anItemTree, otherwise a subset
 */
- (BOOL) writeItemGraph: (COItemGraph*)anItemTree
                     revisionUUID: (ETUUID *)aRevisionUUID
                     withMetadata: (NSDictionary *)metadata
                       withParent: (int64_t)aParent
                  withMergeParent: (int64_t)aMergeParent
                       branchUUID: (ETUUID *)aBranchUUID
               persistentrootUUID: (ETUUID *)aPersistentRootUUID
                            error: (NSError **)error
{
#ifdef VALIDATE_ITEM_GRAPHS
	if (aParent == -1)
	{
		COValidateItemGraph(anItemTree);
	}
	else
	{
		COItemGraph *combinedGraph = [self itemGraphForRevid: aParent];
		[combinedGraph addItemGraph: anItemTree];
		COValidateItemGraph(combinedGraph);
	}
#endif

    NSParameterAssert(aParent >= -1);
    NSParameterAssert(aMergeParent >= -1);
    NSParameterAssert(aRevisionUUID != nil);
    NSParameterAssert(aBranchUUID != nil);
    NSParameterAssert(aPersistentRootUUID != nil);
    NSParameterAssert([anItemTree rootItemUUID] != nil);
	
    [self beginTransaction];
    
    const int64_t parent_deltabase = [self deltabaseForRowid: aParent];
    const int64_t rowid = [self nextRowid];
    const int64_t lastBytesInDeltaRun = [self bytesInDeltaRunForRowid: rowid - 1];
    int64_t deltabase;
    NSData *contentsBlob;
    int64_t bytesInDeltaRun;
    
    // Limit delta runs to 50 commits
    const BOOL delta = (parent_deltabase != -1 && rowid - parent_deltabase < _store.maxNumberOfDeltaCommits);
    
    // Limit delta runs to 4k
    //const BOOL delta = (parent_deltabase != -1 && lastBytesInDeltaRun < 4096);
    if (delta)
    {
        deltabase = parent_deltabase;
        contentsBlob = contentsBLOBWithItemTree(anItemTree);
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
        
        contentsBlob = contentsBLOBWithItemTree(combinedGraph);
        bytesInDeltaRun = [contentsBlob length];
    }

    NSData *metadataBlob = nil;
    if (metadata != nil)
    {
        metadataBlob = CODataWithJSONObject(metadata, NULL);
    }
    
    BOOL ok = [db_ executeUpdate: @"INSERT INTO commits (revid, backinguuid, "
        "contents, hash, metadata, timestamp, parent, mergeparent, branchuuid, persistentrootuuid, deltabase, "
        "bytesInDeltaRun, garbage, uuid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)",
        [NSNumber numberWithLongLong: rowid],
        [_uuid dataValue],
        contentsBlob,
		Sha1Data(contentsBlob),
        metadataBlob,
        CODateToJavaTimestamp([NSDate date]),
        [NSNumber numberWithLongLong: aParent],
        [NSNumber numberWithLongLong: aMergeParent],
		[aBranchUUID dataValue],
		[aPersistentRootUUID dataValue],
        [NSNumber numberWithLongLong: deltabase],
        [NSNumber numberWithLongLong: bytesInDeltaRun],
        [aRevisionUUID dataValue]];
	
	
	// Update the root object UUID
	ETUUID *currentRoot = [self rootUUID];
	
	if (currentRoot == nil)
	{
		ok = ok && [db_ executeUpdate: @"INSERT INTO backingmetadata (backinguuid, root) VALUES (?, ?)",
                 [_uuid dataValue],
		 [[anItemTree rootItemUUID] dataValue]];
	}
	else if (![currentRoot isEqual: [anItemTree rootItemUUID]])
	{
		[self rollback];
		return NO;
	}
	
	[self commit];
    
    return ok;
}

- (NSIndexSet *) revidsFromRevid: (int64_t)baseRevid toRevid: (int64_t)revid
{
    NSParameterAssert(baseRevid <= revid);
    
    NSMutableIndexSet *result = [NSMutableIndexSet indexSet];

    FMResultSet *rs = [db_ executeQuery: @"SELECT revid, parent "
                                          "FROM commits "
                                          "WHERE revid <= ? AND revid >= ? AND backinguuid = ? "
                                          "ORDER BY revid DESC",
                        [NSNumber numberWithLongLong: revid],
                        [NSNumber numberWithLongLong: baseRevid],
                        [_uuid dataValue]];
    
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

	NSAssert([result containsIndex: baseRevid] && [result containsIndex: revid],
		@"-revidsFromRevid:toRevid: given invalid arguments");

    return result;
}

- (BOOL) deleteRevids: (NSIndexSet *)revids
{
    [self beginTransaction];
    
    for (NSUInteger i = [revids firstIndex]; i != NSNotFound; i = [revids indexGreaterThanIndex: i])
    {
        [db_ executeUpdate: @"UPDATE commits SET garbage = 1 WHERE revid = ?",
            [NSNumber numberWithUnsignedInteger: i]];
    }

    // Debugging:
	
    // Example which can be pasted in the sqlite3 prompt to experiment with this query:
    
    /*
     
     drop table c;
     create table c (revid integer, deltabase integer, parent integer, garbage boolean);
     
     insert into c values(0,0,-1,0);
     insert into c values(1,0,0,1); -- marked as garbage, will be selected for deletion
     
     insert into c values(2,2,1,1); -- marked as garbage, will be selected for deletion
     insert into c values(3,2,2,1); -- marked as garbage, will be selected for deletion
     
     insert into c values(4,4,3,0);
     insert into c values(5,4,4,0);
     
     insert into c values(6,6,5,0);
     insert into c values(7,6,6,1); -- marked as garbage, will be selected for deletion
     insert into c values(8,6,7,0); -- will be rebuit because it's not a full snapshot, but its parent is being deleted
     
	 
	 -- Identifies the revisions that need to be rebuilt:
	 
	 SELECT revid
	 FROM c
	 LEFT OUTER JOIN (SELECT garbage AS parentgarbage, revid AS parentrevid FROM c)
	 ON (parent = parentrevid)
	 WHERE garbage = 0 AND parentgarbage = 1 AND deltabase != revid;
	 
     */
	
	// Gather the set of revids that need to be rebuilt
	NSMutableIndexSet *rebuildRevids = [NSMutableIndexSet indexSet];
	FMResultSet *rs = [db_ executeQuery: @"SELECT revid "
                            "FROM commits "
                            "LEFT OUTER JOIN (SELECT garbage AS parentgarbage, revid AS parentrevid FROM commits) "
                            "ON (parent = parentrevid) "
                            "WHERE garbage = 0 AND parentgarbage = 1 AND deltabase != revid AND backinguuid = ?", [_uuid dataValue]];
	while ([rs next])
	{
		[rebuildRevids addIndex: [rs longLongIntForColumnIndex: 0]];
	}
	[rs close];
	
	// Rebuild each revision that needs it
	[rebuildRevids enumerateIndexesUsingBlock: ^(NSUInteger revid, BOOL *stop) {
		COItemGraph *graph = [self itemGraphForRevid: revid];
		
		// GC unreachable items in graph
		[graph removeUnreachableItems];
		
		NSData *contentsBlob = contentsBLOBWithItemTree(graph);
		NSNumber *deltabase = @(revid);
		NSNumber *bytesInDeltaRun = @(contentsBlob.length);
		
		BOOL ok = [db_ executeUpdate: @"UPDATE commits SET contents = ?, hash = ?, deltabase = ?, bytesInDeltaRun = ? WHERE revid = ?",
				   contentsBlob,
				   Sha1Data(contentsBlob),
				   deltabase,
				   bytesInDeltaRun,
				   @(revid)];

		if (!ok)
		{
			[db_ rollback];
			ETAssertUnreachable();
		}
	}];
	
	// Delete _all_ revisions marked as garbage.
    [db_ executeUpdate: @"DELETE FROM commits WHERE garbage = 1 AND backinguuid = ?", [_uuid dataValue]];

    [self commit];
    
    return ![db_ hadError];
}

- (NSIndexSet *) revidsUsedRange
{
	// NOTE: For performance, we use two distinct queries, see
	// http://stackoverflow.com/questions/11515165/sqlite3-select-min-max-together-is-much-slower-than-select-them-separately
    NSNumber *min = [db_ numberForQuery: @"SELECT MIN(rowid) FROM commits WHERE backinguuid = ?", [_uuid dataValue]];
    NSNumber *max = [db_ numberForQuery: @"SELECT MAX(rowid) FROM commits WHERE backinguuid = ?", [_uuid dataValue]];

	if (min == nil && max == nil)
	{
		return [NSIndexSet new];
	}
	NSAssert(min != nil && max != nil, @"The backing store database is returning incoherent results");

	NSUInteger length = max.longLongValue - min.longLongValue + 1;

	return [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(min.longLongValue, length)];
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
		metadata = COJSONObjectWithData(data, NULL);
	}
	
	CORevisionInfo *rev = [CORevisionInfo new];

	[rev setRevisionUUID: uuid];
	[rev setParentRevisionUUID: (id)[NSNumber numberWithLongLong: parent]];
	[rev setMergeParentRevisionUUID: (id)[NSNumber numberWithLongLong: mergeparent]];
	[rev setPersistentRootUUID: [ETUUID UUIDWithData: [rs dataForColumn: @"persistentrootuuid"]]];
	[rev setBranchUUID: [ETUUID UUIDWithData: [rs dataForColumn: @"branchuuid"]]];
	[rev setMetadata: metadata];
	[rev setDate: CODateFromJavaTimestamp([rs numberForColumn: @"timestamp"])];
	
	int64_t revid = [rs longLongIntForColumn: @"revid"];

	/* Memorize the revision ID to support resolving parent and merge parent 
	   revision IDs once revIDs contains all the revisions */

	[revIDs setObject: [rev revisionUUID]
			   forKey: [NSNumber numberWithLongLong: revid]];

	 return rev;
}

- (void)resolveRevisionIDsInRevisionsInfos: (NSArray *)revInfos
                          usingRevisionIDs: (NSDictionary *)revIDs
{
	for (CORevisionInfo *revInfo in revInfos)
	{
		[revInfo setParentRevisionUUID: [revIDs objectForKey: [revInfo parentRevisionUUID]]];
		[revInfo setMergeParentRevisionUUID: [revIDs objectForKey: [revInfo mergeParentRevisionUUID]]];

		ETAssert([revInfo parentRevisionUUID] != nil || [revInfo isEqual: [revInfos firstObject]]);
	}
}

- (NSArray *)revisionInfosForBranchUUID: (ETUUID *)aBranchUUID
                       headRevisionUUID: (ETUUID *)aHeadRevUUID
                                options: (COBranchRevisionReadingOptions)options
{
	NILARG_EXCEPTION_TEST(aBranchUUID);
	FMResultSet *rs = nil;

	if (options & COBranchRevisionReadingDivergentRevisions)
	{
		rs = [db_ executeQuery:
			@"SELECT revid, parent, branchuuid, persistentrootuuid, metadata, timestamp, mergeparent, uuid "
		 	 "FROM commits WHERE revid BETWEEN 0 AND (SELECT MAX(revid) FROM commits WHERE branchuuid = ? AND backinguuid = ?) AND backinguuid = ? "
                      "ORDER BY revid DESC", [aBranchUUID dataValue], [_uuid dataValue], [_uuid dataValue]];
	}
	else
	{
		int64_t headRevid = [self revidForUUID: aHeadRevUUID];

                rs = [db_ executeQuery:
			@"SELECT revid, parent, branchuuid, persistentrootuuid, metadata, timestamp, mergeparent, uuid "
			 "FROM commits WHERE revid BETWEEN 0 AND ? AND backinguuid = ? ORDER BY revid DESC",
			 [NSNumber numberWithLongLong: headRevid],
                        [_uuid dataValue]];
	}

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

- (NSArray *)revisionInfos
{
	FMResultSet *rs = [db_ executeQuery: @"SELECT revid, parent, branchuuid, persistentrootuuid, metadata, timestamp, mergeparent, uuid "
                           "FROM commits WHERE backinguuid = ? ORDER BY revid DESC", [_uuid dataValue]];
	
	NSUInteger suggestedMaxRevCount = 50000;
	NSMutableArray *revInfos = [NSMutableArray arrayWithCapacity: suggestedMaxRevCount];
	NSMutableDictionary *revIDs = [NSMutableDictionary dictionaryWithCapacity: suggestedMaxRevCount];
	
	while ([rs next])
	{
		[revInfos insertObject: [self revisionInfoWithResultSet: rs revisionIDs: revIDs]
					   atIndex: 0];
    }
	[rs close];
	
	[self resolveRevisionIDsInRevisionsInfos: revInfos
							usingRevisionIDs: revIDs];
	
	return revInfos;
}

- (uint64_t) fileSize
{
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath: [db_ databasePath]
																		   error: NULL];
	
	return [attrs[NSFileSize] unsignedLongLongValue];
}

@end
