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
#import "COUndoTrack.h"

@implementation COHistoryCompaction

@synthesize undoTrack = _undoTrack;

- (instancetype)initWithUndoTrack: (COUndoTrack *)aTrack upToCommand: (COCommand *)aCommand
{
	SUPERINIT;
	_undoTrack = aTrack;
	_oldestCommandToKeep = aCommand;
	_deadPersistentRootUUIDs = [NSMutableSet setWithCapacity: 50000];
	_livePersistentRootUUIDs = [NSMutableSet setWithCapacity: 50000];
	_deadRevisionUUIDs = [NSMutableSet setWithCapacity: 500000];
	_liveRevisionUUIDs = [NSMutableSet setWithCapacity: 500000];
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
 * Scanning to decide which revisions are alive, based on whether their
 * branch or persistent root are alive as computed by -scanPersistentRoots.
 */
- (void)scanRevisions
{
	BOOL isScanningLiveCommands = NO;

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
	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		[_deadRevisionUUIDs addObject: [command revisionUUID]];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		[_deadRevisionUUIDs removeObject: [command initialRevisionID]];
	}
	
	ETAssert(_liveRevisionUUIDs.isEmpty);
}

- (void)scanRevisionInLiveCommand: (id)command
{
	if ([command isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		BOOL isDeadPersistentRoot =
			[_deadPersistentRootUUIDs containsObject: [command persistentRootUUID]];
		NSMutableSet *addedRevisionUUIDs;
		NSMutableSet *removedRevisionUUIDs;

		// TODO: We'll need something more precise when we check branch aliveness
		addedRevisionUUIDs = isDeadPersistentRoot ? _deadRevisionUUIDs : _liveRevisionUUIDs;
		removedRevisionUUIDs = isDeadPersistentRoot ? _liveRevisionUUIDs : _deadRevisionUUIDs;

		[addedRevisionUUIDs addObject: [command oldRevisionUUID]];
		[removedRevisionUUIDs removeObject: [command oldRevisionUUID]];
		
		[addedRevisionUUIDs addObject: [command revisionUUID]];
		[removedRevisionUUIDs removeObject: [command revisionUUID]];
		
		[addedRevisionUUIDs addObject: [command oldHeadRevisionUUID]];
		[removedRevisionUUIDs removeObject: [command oldHeadRevisionUUID]];
		
		[addedRevisionUUIDs addObject: [command headRevisionUUID]];
		[removedRevisionUUIDs removeObject: [command headRevisionUUID]];
	}
	else if ([command isKindOfClass: [COCommandUndeletePersistentRoot class]])
	{
		[_deadRevisionUUIDs removeObject: [command initialRevisionID]];
		[_liveRevisionUUIDs addObject: [command initialRevisionID]];
	}
}

@end
