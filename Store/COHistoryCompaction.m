/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "COHistoryCompaction.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface COSQLiteStore ()
- (void)deleteBackingStoreWithUUID: (ETUUID *)aUUID;
- (COSQLiteStorePersistentRootBackingStore *) backingStoreForUUID: (ETUUID *)aUUID error: (NSError **)error;
- (BOOL)finalizeGarbageAttachments;
@end

@implementation COSQLiteStore (COHistoryCompaction)

- (BOOL)compactHistory: (id <COHistoryCompaction>)aCompactionStrategy
{
    NILARG_EXCEPTION_TEST(aCompactionStrategy);
    ETAssert(dispatch_get_current_queue() != queue_);
    
    dispatch_sync(queue_, ^()
	{
        [db_ beginTransaction];
        
        // Delete rows from branches and persistentroots tables
		
		for (ETUUID *persistentRoot in aCompactionStrategy.deadPersistentRootUUIDs)
		{
			NSData *persistentRootData = [persistentRoot dataValue];
			
			[db_ executeUpdate: @"DELETE FROM branches WHERE deleted = 1 AND proot = ?", persistentRootData];
			
			if ([db_ boolForQuery: @"SELECT deleted FROM persistentroots WHERE uuid = ?", persistentRootData])
			{
				[db_ executeUpdate: @"DELETE FROM branches WHERE proot = ?", persistentRootData];
				[db_ executeUpdate: @"DELETE FROM persistentroots WHERE uuid = ?", persistentRootData];
			}
		}

		// Delete unused backing stores
		
		NSArray *unusedBackingstoreUUIDDatas =
			[db_ arrayForQuery: @"SELECT backingstore "
			 "FROM persistentroot_backingstores "
			 "LEFT OUTER JOIN (SELECT uuid, 1 AS present FROM persistentroots) USING(uuid) "
			 "GROUP BY backingstore "
			 "HAVING 0 = COALESCE(SUM(present), 0)"];
		for (NSData *backingstoreUUIDData in unusedBackingstoreUUIDDatas)
		{
			[self deleteBackingStoreWithUUID: [ETUUID UUIDWithData: backingstoreUUIDData]];
		}
		
		// Gather backing stores that need revision GC
		
		NSMutableSet *backingStoresForRevisionGC = [NSMutableSet new];
		NSMutableDictionary *persistentRootsByBackingStore = [NSMutableDictionary new];

		for (ETUUID *persistentRoot in aCompactionStrategy.livePersistentRootUUIDs)
		{
			NSData *persistentRootData = [persistentRoot dataValue];
			NSData *backingStoreData = [db_ dataForQuery: @"SELECT backingstore FROM persistentroot_backingstores WHERE uuid = ?", persistentRootData];
						
			// Don't attempt revision GC on backing stores we just deleted
			if (![unusedBackingstoreUUIDDatas containsObject: backingStoreData])
			{
				ETUUID *backingStore = [ETUUID UUIDWithData: backingStoreData];

				[backingStoresForRevisionGC addObject: backingStore];
				
				if (persistentRootsByBackingStore[backingStore] == nil)
				{
					persistentRootsByBackingStore[backingStore] = [NSMutableArray new];
				}
				[persistentRootsByBackingStore[backingStore] addObject: persistentRoot];
			}
		}
		
		// Do the revision GC
		
		for (ETUUID *backingUUID in backingStoresForRevisionGC)
		{
			NSData *backingUUIDData = [backingUUID dataValue];
		
			COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: backingUUID error: NULL];
			
			// Delete just the unreachable revisions
			
			NSArray *persistentRootUUIDs = persistentRootsByBackingStore[backingUUID];
			NSSet *liveRevisionUUIDs = [aCompactionStrategy liveRevisionUUIDsForPersistentRootUUIDs: persistentRootUUIDs];
			NSIndexSet *keptRevisions = nil;
			NSIndexSet *revisions = [backing revidsUsedRange];
			
			if (liveRevisionUUIDs.isEmpty)
			{
				FMResultSet *rs = [db_ executeQuery: @"SELECT "
								   "branches.current_revid "
								   "FROM persistentroots "
								   "INNER JOIN branches ON persistentroots.uuid = branches.proot "
								   "INNER JOIN persistentroot_backingstores ON persistentroots.uuid = persistentroot_backingstores.uuid "
								   "WHERE persistentroot_backingstores.backingstore = ?", backingUUIDData];
				
				keptRevisions = [NSMutableIndexSet new];

				while ([rs next])
				{
					ETUUID *head = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
					
					NSIndexSet *revs = [backing revidsFromRevid: 0
														toRevid: [backing revidForUUID: head]];
					[(NSMutableIndexSet *)keptRevisions addIndexes: revs];
				}
				[rs close];
			}
			else
			{
				NSIndexSet *liveRevisions = [backing revidsForUUIDs: liveRevisionUUIDs.allObjects];
				
				/* Join the live revisions into a single range to determine the kept revisions */
				ETAssert(liveRevisions.lastIndex <= revisions.lastIndex);
				NSUInteger length = revisions.lastIndex - liveRevisions.firstIndex + 1;
				NSRange liveRange = NSMakeRange(liveRevisions.firstIndex, length);
				
				keptRevisions = [NSIndexSet indexSetWithIndexesInRange: liveRange];
			}
			
			// Now for each index set in deletedRevisionsForBackingStore, subtract the index set
			// in keptRevisionsForBackingStore
			
			NSMutableIndexSet *deletedRevisions = [NSMutableIndexSet indexSet];
			[deletedRevisions addIndexes: revisions];
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
			
			// Delete the actual revisions
			assert([backing deleteRevids: deletedRevisions]);
		}
		
		assert([db_ commit]);
		
        [self finalizeGarbageAttachments];
    });
    
    return YES;
}

@end
