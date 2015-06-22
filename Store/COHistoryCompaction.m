/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "COHistoryCompaction.h"
#import "COCommand.h"
#import "COCommandDeletePersistentRoot.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COSQLiteStorePersistentRootBackingStore.h"
#import "COUndoTrack.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#define PERSISTENT_ROOT_CAPACITY_HINT 25000

@implementation COHistoryCompaction

@synthesize undoTrack = _undoTrack, deadPersistentRootUUIDs = _deadPersistentRootUUIDs,
	livePersistentRootUUIDs = _livePersistentRootUUIDs,
	deadRevisionUUIDs = _deadRevisionUUIDs, liveRevisionUUIDs = _liveRevisionUUIDs;

- (instancetype)initWithUndoTrack: (COUndoTrack *)aTrack upToCommand: (COCommand *)aCommand
{
	SUPERINIT;
	_undoTrack = aTrack;
	_oldestCommandToKeep = aCommand;
	_deadPersistentRootUUIDs = [NSMutableSet setWithCapacity: PERSISTENT_ROOT_CAPACITY_HINT];
	_livePersistentRootUUIDs = [NSMutableSet setWithCapacity: PERSISTENT_ROOT_CAPACITY_HINT];
	_deadRevisionUUIDs = [NSMutableDictionary dictionaryWithCapacity: PERSISTENT_ROOT_CAPACITY_HINT];
	_liveRevisionUUIDs = [NSMutableDictionary dictionaryWithCapacity: PERSISTENT_ROOT_CAPACITY_HINT];
	return self;
}

- (void)compute
{
	[self scanPersistentRoots];
	[self scanRevisions];
}

/**
 * Forward scanning to decide which persistent roots and branches are alive.
 */
- (void)scanPersistentRoots
{
	BOOL isScanningLiveCommands = NO;

	for (COCommand *command in _undoTrack.allCommands)
	{
		isScanningLiveCommands = isScanningLiveCommands || [command isEqual: _oldestCommandToKeep];

		if (isScanningLiveCommands)
		{
			[self scanPersistentRootInLiveCommand: command];
		}
		else
		{
			[self scanPersistentRootInDeadCommand: command];
		}
	}
}

/**
 * A this point, we know the exact dead and live persistent root sets, so we
 * we don't have to collect revisions for dead persistent roots.
 */
- (void)allocateRevisionSets
{
	for (ETUUID *persistentRootUUID in _livePersistentRootUUIDs)
	{
		_deadRevisionUUIDs[persistentRootUUID] = [NSMutableSet set];
		_liveRevisionUUIDs[persistentRootUUID] = [NSMutableSet set];
	}
}

/** 
 * Scanning to decide which revisions are alive, based on whether their
 * branch or persistent root are alive as computed by -scanPersistentRoots.
 */
- (void)scanRevisions
{
	BOOL isScanningLiveCommands = NO;
	
	[self allocateRevisionSets];

	for (COCommand *command in [_undoTrack.allCommands reverseObjectEnumerator])
	{
		isScanningLiveCommands = isScanningLiveCommands || [command isEqual: _oldestCommandToKeep];

		if (isScanningLiveCommands)
		{
			[self scanRevisionInLiveCommand: command];
		}
		else
		{
			[self scanRevisionInDeadCommand: command];
		}
	}
}

- (void)scanPersistentRootInDeadCommand: (COCommand *)command
{
	if ([command isKindOfClass: [COCommandDeletePersistentRoot class]])
	{
		[_deadPersistentRootUUIDs addObject: command.persistentRootUUID];
		[_livePersistentRootUUIDs removeObject: command.persistentRootUUID];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		/* This can represent COCommandCreatePersistentRoot too.
		   Don't delete alive persistent roots, even when we committed no 
		   changes following the oldest command to keep. */
		[_deadPersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_livePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
}

- (void)scanPersistentRootInLiveCommand: (COCommand *)command
{
	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		/* If we commit changes to a deleted persistent root after the oldest 
		   command to keep, we want to keep this persistent root alive */
		[_deadPersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_livePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
	else if ([command isKindOfClass: [COCommandDeletePersistentRoot class]])
	{
		[_deadPersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_livePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		[_deadPersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_livePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
	else
	{
		ETAssertUnreachable();
	}
}

- (void)scanRevisionInDeadCommand: (id)command
{
	ETUUID *persistentRootUUID = [command persistentRootUUID];

	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		[_deadRevisionUUIDs[persistentRootUUID] addObject: [command revisionUUID]];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		[_deadRevisionUUIDs[persistentRootUUID] removeObject: [command initialRevisionID]];
	}
	
	ETAssert(_liveRevisionUUIDs.isEmpty);
}

- (void)scanRevisionInLiveCommand: (id)command
{
	ETUUID *persistentRootUUID = [command persistentRootUUID];

	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		ETAssert(![_deadPersistentRootUUIDs containsObject: [command persistentRootUUID]]);

		// TODO: We'll need something more precise when we check branch aliveness

		[_deadRevisionUUIDs[persistentRootUUID] removeObject: [command oldRevisionUUID]];
		[_liveRevisionUUIDs[persistentRootUUID] addObject: [command oldRevisionUUID]];

		[_deadRevisionUUIDs[persistentRootUUID] removeObject: [command revisionUUID]];
		[_liveRevisionUUIDs[persistentRootUUID] addObject: [command revisionUUID]];

		[_deadRevisionUUIDs[persistentRootUUID] removeObject: [command oldHeadRevisionUUID]];
		[_liveRevisionUUIDs[persistentRootUUID] addObject: [command oldHeadRevisionUUID]];

		[_deadRevisionUUIDs[persistentRootUUID] removeObject: [command headRevisionUUID]];
		[_liveRevisionUUIDs[persistentRootUUID] addObject: [command headRevisionUUID]];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		[_deadRevisionUUIDs[persistentRootUUID] removeObject: [command initialRevisionID]];
		[_liveRevisionUUIDs[persistentRootUUID] addObject: [command initialRevisionID]];
	}
}

- (NSSet *)deadRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs
{
	NSMutableSet *revisionUUIDs = [NSMutableSet new];
	
	for (NSSet *revisionSet in [_deadRevisionUUIDs objectsForKeys: persistentRootUUIDs
	                                               notFoundMarker: nil])
	{
		[revisionUUIDs unionSet: revisionSet];
	}
	return revisionUUIDs;
}

- (NSSet *)liveRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs
{
	NSMutableSet *revisionUUIDs = [NSMutableSet new];
	
	for (NSSet *revisionSet in [_liveRevisionUUIDs objectsForKeys: persistentRootUUIDs
	                                               notFoundMarker: nil])
	{
		[revisionUUIDs unionSet: revisionSet];
	}
	return revisionUUIDs;
}

@end


@interface COSQLiteStore ()
- (void)deleteBackingStoreWithUUID: (ETUUID *)aUUID;
- (COSQLiteStorePersistentRootBackingStore *) backingStoreForUUID: (ETUUID *)aUUID error: (NSError **)error;
- (BOOL)finalizeGarbageAttachments;
@end

@implementation COSQLiteStore (COHistoryCompaction)

- (BOOL)compactHistory: (COHistoryCompaction *)aCompactionStrategy
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
