/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "COHistoryCompaction.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "COSQLiteUtilities.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

/* For dispatch_get_current_queue() deprecated on iOS (to prevent to people to 
   use it beside debugging) */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface COSQLiteStore ()

- (void)deleteBackingStoreWithUUID: (ETUUID *)aUUID;
- (COSQLiteStorePersistentRootBackingStore *)backingStoreForUUID: (ETUUID *)aUUID
                                                           error: (NSError **)error;
- (BOOL)finalizeGarbageAttachments;
- (void)postCommitNotificationsWithTransactionIDForPersistentRootUUID: (NSDictionary *)txnIDForPersistentRoot
                                              insertedPersistentRoots: (NSArray *)insertedUUIDs
                                               deletedPersistentRoots: (NSArray *)deletedUUIDs
                                             compactedPersistentRoots: (NSArray *)compactedUUIDs
                                             finalizedPersistentRoots: (NSArray *)finalizedUUIDs;

@end


@implementation COSQLiteStore (COHistoryCompaction)

- (BOOL)compactHistory: (id <COHistoryCompaction>)aCompactionStrategy
{
    NILARG_EXCEPTION_TEST(aCompactionStrategy);
    ETAssert(dispatch_get_current_queue() != queue_);

    __block NSMutableSet *compactedPersistentRootUUIDs = [NSMutableSet new];
    __block NSMutableSet *finalizedPersistentRootUUIDs = [NSMutableSet new];

    dispatch_sync_now(dispatch_get_main_queue(), ^()
    {
        [aCompactionStrategy beginCompaction];
    });

    dispatch_sync(queue_, ^()
    {
        [db_ beginTransaction];

        NSMutableSet *collectablePersistentRootUUIDs = [NSMutableSet new];

        [collectablePersistentRootUUIDs unionSet: aCompactionStrategy.compactablePersistentRootUUIDs];
        [collectablePersistentRootUUIDs unionSet: aCompactionStrategy.finalizablePersistentRootUUIDs];

        // NOTE: We pretend all compactable persistent roots end up being
        // compacted (this will cause an useless reloading in COPersistentRoot),
        // but this is less complex/costly than computing precisely which
        // persistent roots are compacted when deleting revisions in a backing store.
        [compactedPersistentRootUUIDs unionSet: aCompactionStrategy.compactablePersistentRootUUIDs];

        // Delete rows from branches and persistentroots tables

        for (ETUUID *persistentRoot in aCompactionStrategy.finalizablePersistentRootUUIDs)
        {
            NSData *persistentRootData = [persistentRoot dataValue];

            [db_ executeUpdate: @"DELETE FROM branches WHERE deleted = 1 AND proot = ?",
                                persistentRootData];

            if ([db_ boolForQuery: @"SELECT deleted FROM persistentroots WHERE uuid = ?",
                                   persistentRootData])
            {
                [db_ executeUpdate: @"DELETE FROM branches WHERE proot = ?", persistentRootData];
                [db_ executeUpdate: @"DELETE FROM persistentroots WHERE uuid = ?",
                                    persistentRootData];

                [finalizedPersistentRootUUIDs addObject: persistentRoot];
            }
        }

        for (ETUUID *branchUUID in aCompactionStrategy.finalizableBranchUUIDs)
        {
            FMResultSet *rs = [db_ executeQuery:
                @"SELECT proot FROM branches WHERE uuid = ?", branchUUID.dataValue];

            if ([rs next])
            {
                ETUUID *UUID = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];

                [collectablePersistentRootUUIDs addObject: UUID];
                [compactedPersistentRootUUIDs addObject: UUID];

                ETAssert(![rs next]);
            }
            [rs close];

            [db_ executeUpdate: @"DELETE FROM branches WHERE deleted = 1 AND uuid = ?",
                                branchUUID.dataValue];
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

        for (ETUUID *persistentRoot in collectablePersistentRootUUIDs)
        {
            NSData *persistentRootData = [persistentRoot dataValue];
            NSData *backingStoreData = [db_ dataForQuery: @"SELECT backingstore FROM persistentroot_backingstores WHERE uuid = ?",
                                                          persistentRootData];

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
            COSQLiteStorePersistentRootBackingStore *backing = [self backingStoreForUUID: backingUUID
                                                                                   error: NULL];
            NSIndexSet *revisions = backing.revidsUsedRange;
            NSMutableIndexSet *reachableRevisions = [NSMutableIndexSet new];
            NSMutableIndexSet *contiguousLiveRevisions = [NSMutableIndexSet new];

            // Find reachable revisions

            FMResultSet *rs = [db_ executeQuery: @"SELECT "
                                                  "branches.head_revid "
                                                  "FROM persistentroots "
                                                  "INNER JOIN branches ON persistentroots.uuid = branches.proot "
                                                  "INNER JOIN persistentroot_backingstores ON persistentroots.uuid = persistentroot_backingstores.uuid "
                                                  "WHERE persistentroot_backingstores.backingstore = ?",
                                                 backingUUIDData];

            while ([rs next])
            {
                ETUUID *head = [ETUUID UUIDWithData: [rs dataForColumnIndex: 0]];
                // TODO: Could be better to pass the tail revid
                NSIndexSet *revs = [backing revidsFromRevid: revisions.firstIndex
                                                    toRevid: [backing revidForUUID: head]];
                [reachableRevisions addIndexes: revs];
            }
            [rs close];

            // Join live revisions into a single contiguous range

            // FIXME: Include non-deleted branches initial revisions in the
            // contiguous range, otherwise branches untouched in the history
            // recently could have their revisions discarded.

            NSArray *persistentRootUUIDs = persistentRootsByBackingStore[backingUUID];
            NSSet *liveRevisionUUIDs =
                [aCompactionStrategy liveRevisionUUIDsForPersistentRootUUIDs: persistentRootUUIDs];
            const BOOL canDeleteReachableRevisions = !liveRevisionUUIDs.isEmpty;

            if (canDeleteReachableRevisions)
            {
                NSIndexSet *liveRevisions = [backing revidsForUUIDs: liveRevisionUUIDs.allObjects];
                ETAssert(liveRevisions.lastIndex <= revisions.lastIndex);
                NSUInteger length = revisions.lastIndex - liveRevisions.firstIndex + 1;
                NSRange liveRange = NSMakeRange(liveRevisions.firstIndex, length);

                // TODO: Keep at least one revision for a non-deleted persistent
                // root not referenced by any command in the undo track.
                [contiguousLiveRevisions addIndexesInRange: liveRange];
            }

            // Compute deleted revisions (unreachable or outside live range)

            /* Contiguous live revisions can contain unreachable revisions 
               referenced by an undo track. For example, committing after an 
               undo turns the undone revisions into divergent ones (and 
               unreachable since not owned by a branch). If the head changes, 
               revisions beyond it becomes unreachable (but once again an undo
               undo track could reference them).
               In other words, reachable revisions and contiguous live revisions
               can overlap (there is no subset relationship between them). */

            // TODO: Decide whether the first contiguous live revision could ever
            // precede the first reachable revision (probably not).
            //ETAssert(reachableRevisions.firstIndex <= contiguousLiveRevisions.firstIndex);

            NSMutableIndexSet *deletedRevisions = [NSMutableIndexSet indexSet];
            NSIndexSet *keptRevisions =
                (canDeleteReachableRevisions ? contiguousLiveRevisions : reachableRevisions);

            [deletedRevisions addIndexes: revisions];
            [deletedRevisions removeIndexes: keptRevisions];

            [deletedRevisions enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *stop)
            {
                // TODO: We should probably change attachment_refs to store
                // revid as INTEGER rather than BLOB (same for proot_refs)
                [db_ executeUpdate: @"DELETE FROM attachment_refs WHERE root_id = ? AND revid = ?",
                                    backingUUID.dataValue,
                                    [backing revisionUUIDForRevid: i].dataValue];

                // FIXME: FTS, proot_refs
            }];

            // Delete the actual revisions

            assert([backing deleteRevids: deletedRevisions]);
        }

        assert([db_ commit]);

        [self finalizeGarbageAttachments];
    });

    dispatch_sync_now(dispatch_get_main_queue(), ^()
    {
        [aCompactionStrategy endCompaction: YES];

        [self postCommitNotificationsWithTransactionIDForPersistentRootUUID: @{}
                                                    insertedPersistentRoots: @[]
                                                     deletedPersistentRoots: @[]
                                                   compactedPersistentRoots: compactedPersistentRootUUIDs.allObjects
                                                   finalizedPersistentRoots: finalizedPersistentRootUUIDs.allObjects];
    });

    return YES;
}

@end
