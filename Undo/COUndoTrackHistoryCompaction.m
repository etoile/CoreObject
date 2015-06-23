/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "COUndoTrackHistoryCompaction.h"
#import "COCommand.h"
#import "COCommandDeletePersistentRoot.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COUndoTrack.h"


#define PERSISTENT_ROOT_CAPACITY_HINT 25000

@implementation COUndoTrackHistoryCompaction

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
