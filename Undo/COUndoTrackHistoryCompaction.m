/*
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import "COUndoTrackHistoryCompaction.h"
#import "COCommand.h"
#import "COCommandGroup.h"
#import "COCommandDeletePersistentRoot.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COUndoTrack.h"


#define PERSISTENT_ROOT_CAPACITY_HINT 25000
#define BRANCH_CAPACITY_HINT PERSISTENT_ROOT_CAPACITY_HINT

@implementation COUndoTrackHistoryCompaction

@synthesize undoTrack = _undoTrack, finalizablePersistentRootUUIDs = _finalizablePersistentRootUUIDs,
	compactablePersistentRootUUIDs = _compactablePersistentRootUUIDs,
	finalizableBranchUUIDs = _finalizableBranchUUIDs,
	compactableBranchUUIDs = _compactableBranchUUIDs,
	deadRevisionUUIDs = _deadRevisionUUIDs, liveRevisionUUIDs = _liveRevisionUUIDs;

- (instancetype)initWithUndoTrack: (COUndoTrack *)aTrack upToCommand: (COCommand *)aCommand
{
	SUPERINIT;
	_undoTrack = aTrack;
	_oldestCommandToKeep = aCommand;
	_finalizablePersistentRootUUIDs = [NSMutableSet setWithCapacity: PERSISTENT_ROOT_CAPACITY_HINT];
	_compactablePersistentRootUUIDs = [NSMutableSet setWithCapacity: PERSISTENT_ROOT_CAPACITY_HINT];
	_finalizableBranchUUIDs = [NSMutableSet setWithCapacity: BRANCH_CAPACITY_HINT];
	_compactableBranchUUIDs = [NSMutableSet setWithCapacity: BRANCH_CAPACITY_HINT];
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

	for (COCommandGroup *commandGroup in _undoTrack.allCommands)
	{
		isScanningLiveCommands = isScanningLiveCommands || [commandGroup isEqual: _oldestCommandToKeep];

		for (COCommand *command in commandGroup.contents)
		{
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
}

/**
 * A this point, we know the exact dead and live persistent root sets, so we
 * we don't have to collect revisions for dead persistent roots.
 */
- (void)allocateRevisionSets
{
	for (ETUUID *persistentRootUUID in _compactablePersistentRootUUIDs)
	{
		_deadRevisionUUIDs[persistentRootUUID] = [NSMutableSet set];
		_liveRevisionUUIDs[persistentRootUUID] = [NSMutableSet set];
	}
}

/** 
 * Forward scanning to decide which revisions are alive, based on whether their
 * branch or persistent root are alive as computed by -scanPersistentRoots.
 *
 * The forward scanning is important to let -scanRevisionInLiveCommand: takes
 * over -scanRevisionInDeadCommand: to decide whether a revision is dead or alive.
 */
- (void)scanRevisions
{
	BOOL isScanningLiveCommands = NO;
	
	[self allocateRevisionSets];

	// NOTE: If we switch to a backward scanning, then we must change and move
	// to the end isScanningLiveCommands condition and assignment.
	for (COCommandGroup *commandGroup in _undoTrack.allCommands)
	{
		isScanningLiveCommands = isScanningLiveCommands || [commandGroup isEqual: _oldestCommandToKeep];

		for (COCommand *command in commandGroup.contents)
		{
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
}

/**
 * The forward scanning is important in this method.
 *
 * The last status check (deleted vs undeleted) decides whether the persistent 
 * root will be finalized or compacted.
 */
- (void)scanPersistentRootInDeadCommand: (COCommand *)command
{
	if ([command isKindOfClass: [COCommandDeletePersistentRoot class]])
	{
		[_finalizablePersistentRootUUIDs addObject: command.persistentRootUUID];
		[_compactablePersistentRootUUIDs removeObject: command.persistentRootUUID];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		/* This can represent COCommandCreatePersistentRoot too.
		   Don't delete alive persistent roots, even when we committed no 
		   changes following the oldest command to keep. */
		[_finalizablePersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_compactablePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
}

/**
 * A persistent root could have been marked as finalizable if 
 * COCommandDeletePersistentRoot was present in dead commands.
 *
 * If COCommandDeletePersistentRoot and COCommandUndeletePersistentRoot are 
 * present in live commands, the persistent root won't marked as finalizable 
 * anymore, so we can continue to replay deletion or undeletion with the undo 
 * track.
 */
- (void)scanPersistentRootInLiveCommand: (COCommand *)command
{
	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		/* If we commit changes to a deleted persistent root after the oldest 
		   command to keep, we want to keep this persistent root alive */
		[_finalizablePersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_compactablePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
	else if ([command isKindOfClass: [COCommandDeletePersistentRoot class]])
	{
		[_finalizablePersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_compactablePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		[_finalizablePersistentRootUUIDs removeObject: command.persistentRootUUID];
		[_compactablePersistentRootUUIDs addObject: command.persistentRootUUID];
	}
	else
	{
		ETAssertUnreachable();
	}
}

/**
 * Marks revisions created by this command as dead.
 *
 * For COCommandUndeletePersistentRoot and COCommandDeletePersistentRoot, 
 * we don't mark their initial revision as dead, since this revision was not 
 * created by these commands.
 *
 * For COCommandSetCurrentVersionForBranch, we don't mark the old revision, 
 * old head revision and head revision as dead.
 */
- (void)scanRevisionInDeadCommand: (id)command
{
	ETUUID *persistentRootUUID = [command persistentRootUUID];

	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		[_deadRevisionUUIDs[persistentRootUUID] addObject: [command revisionUUID]];
	}
	else if ([command isKindOfClass: [COCommandCreatePersistentRoot class]])
	{
		[_deadRevisionUUIDs[persistentRootUUID] addObject: [command initialRevisionID]];
	}
	ETAssert([_liveRevisionUUIDs[persistentRootUUID] isEmpty]);
}

- (void)scanRevisionInLiveCommand: (id)command
{
	ETUUID *persistentRootUUID = [command persistentRootUUID];

	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		ETAssert(![_finalizablePersistentRootUUIDs containsObject: [command persistentRootUUID]]);

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
	                                               notFoundMarker: [NSNull null]])
	{
		[revisionUUIDs unionSet: revisionSet];
	}
	return revisionUUIDs;
}

- (NSSet *)liveRevisionUUIDsForPersistentRootUUIDs: (NSArray *)persistentRootUUIDs
{
	NSMutableSet *revisionUUIDs = [NSMutableSet new];
	
	for (NSSet *revisionSet in [_liveRevisionUUIDs objectsForKeys: persistentRootUUIDs
	                                               notFoundMarker: [NSNull null]])
	{
		[revisionUUIDs unionSet: revisionSet];
	}
	return revisionUUIDs;
}

@end
