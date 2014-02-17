/*
	Copyright (C) 2014 Eric Wasylishen, Quentin Mathe

	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>

#import "COUndoTrackStore.h"
#import "COUndoTrack.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "COCommandGroup.h"
#import "COEndOfUndoTrackPlaceholderNode.h"
#import "COCommandSetCurrentVersionForBranch.h"

extern NSString * const kCOCommandUUID;

NSString * const COUndoStackDidChangeNotification = @"COUndoStackDidChangeNotification";
NSString * const kCOUndoStackName = @"COUndoStackName";

@interface COPatternUndoTrack : COUndoTrack
@end


@interface COUndoTrack ()
@property (strong, readwrite, nonatomic) COUndoTrackStore *store;
@property (strong, readwrite, nonatomic) NSString *name;
@end

@implementation COUndoTrack

@synthesize name = _name, editingContext = _editingContext, store = _store;

#pragma mark -
#pragma mark Initialization

+ (void) initialize
{
	if (self != [COUndoTrack class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

+ (COUndoTrack *)trackForName: (NSString *)aName
           withEditingContext: (COEditingContext *)aContext
{
	return [[self alloc] initWithStore: [COUndoTrackStore defaultStore]
	                              name: aName
	                    editingContext: aContext];
}

+ (COUndoTrack *)trackForPattern: (NSString *)aPattern
              withEditingContext: (COEditingContext *)aContext
{
	return [[COPatternUndoTrack alloc] initWithStore: [COUndoTrackStore defaultStore]
	                                            name: aPattern
	                                  editingContext: aContext];
}

- (id) initWithStore: (COUndoTrackStore *)aStore
                name: (NSString *)aName
	  editingContext: (COEditingContext *)aContext
{
    SUPERINIT;
    _name = aName;
    _store = aStore;
	_editingContext = aContext;
	_trackStateForName = [NSMutableDictionary new];
	_commandsByUUID = [NSMutableDictionary new];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storeTracksDidChange:)
                                                 name: COUndoTrackStoreTracksDidChangeNotification
                                               object: _store];
	
    return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Track Protocol - Convenience Methods

- (BOOL)canUndo
{
	return [self currentNode] != [COEndOfUndoTrackPlaceholderNode sharedInstance];
}

- (BOOL)canRedo
{
	return [self nextNodeOnTrackFrom: [self currentNode] backwards: NO] != nil;
}

- (void)undo
{
	[self setCurrentNode: [self nextNodeOnTrackFrom: [self currentNode] backwards: YES]];
}

- (void)redo
{
	[self setCurrentNode: [self nextNodeOnTrackFrom: [self currentNode] backwards: NO]];
}

- (id <COTrackNode>)nextNodeOnTrackFrom: (id <COTrackNode>)aNode backwards: (BOOL)back
{
	NSInteger nodeIndex = [[self nodes] indexOfObject: aNode];
	
	if (nodeIndex == NSNotFound)
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"Node %@ must belong to the track %@ to retrieve the previous or next node", aNode, self];
	}
	if (back)
	{
		nodeIndex--;
	}
	else
	{
		nodeIndex++;
	}
	
	BOOL hasNoPreviousOrNextNode = (nodeIndex < 0 || nodeIndex >= [[self nodes] count]);
	
	if (hasNoPreviousOrNextNode)
	{
		return nil;
	}
	return [[self nodes] objectAtIndex: nodeIndex];
}

#pragma mark - Track Protocol - Primitive Methods

- (NSArray *)nodes
{
	[self loadIfNeeded];
	return [_nodesOnCurrentUndoBranch copy];
}

- (id <COTrackNode>)currentNode
{
	id <COTrackNode> result = [self currentCommandGroup];
	if (result == nil)
		result = [COEndOfUndoTrackPlaceholderNode sharedInstance];
	return result;
}

- (BOOL)setCurrentNode: (id <COTrackNode>)node
{
	const NSUInteger currentIndex = [_nodesOnCurrentUndoBranch indexOfObject: [self currentNode]];
	const NSUInteger targetIndex = [_nodesOnCurrentUndoBranch indexOfObject: node];
	
	ETAssert(currentIndex != NSNotFound);
	
	if (targetIndex == NSNotFound)
	{
		NSLog(@"Warning, -setCurrentNode called with %@, which is not on the track's current branch", node);
		return NO;
	}

	if (targetIndex == currentIndex)
		return YES;
	
	[_store beginTransaction];
	
	NSMutableArray *undo1 = [NSMutableArray new];
	NSMutableArray *redo1 = [NSMutableArray new];
	
	if (targetIndex < currentIndex)
	{
		for (NSUInteger i = currentIndex; i > targetIndex; i--)
		{
			[undo1 addObject: _nodesOnCurrentUndoBranch[i]];
		}
	}
	else
	{
		for (NSUInteger i = currentIndex + 1; i <= targetIndex; i++)
		{
			[redo1 addObject: _nodesOnCurrentUndoBranch[i]];
		}
	}
	
	[self undo: undo1 redo: redo1 undo: @[] redo: @[]];
	
	BOOL ok = [_store commitTransaction];
	if (ok)
	{
		[self didUpdate];
	}
	return ok;
}

- (void)undoNode: (id <COTrackNode>)aNode
{
	COUndoTrack *track = [COUndoTrack trackForName: ((COCommandGroup *)aNode).trackName withEditingContext: _editingContext];
	ETAssert(track != nil);
	
	COCommand *command = [(COCommand *)aNode inverse];
	[command applyToContext: _editingContext];
	
	NSString *commitShortDescription = [aNode localizedShortDescription];
	if (commitShortDescription == nil)
		commitShortDescription = @"";
	
	[_editingContext commitWithIdentifier: @"org.etoile.CoreObject.selective-undo"
								 metadata: @{ kCOCommitMetadataShortDescriptionArguments : @[commitShortDescription]}
								undoTrack: track
									error: NULL];
}

- (void)redoNode: (id <COTrackNode>)aNode
{
	
}

#pragma mark - COUndoTrack - Other Public Methods

- (void) recordCommand: (COCommandGroup *)aCommand
{
	ETAssert([aCommand isKindOfClass: [COCommandGroup class]]);

	ETAssert([_trackStateForName count] <= 1);
	COUndoTrackState *state = _trackStateForName[_name];
	
	// Set ownership pointers (not parent UUID!)
	[self setParentPointersForCommandGroup: aCommand];

	[_store beginTransaction];
	
	[self loadIfNeeded];
	
	// Check our state
	COUndoTrackState *storeState = [_store stateForTrackName: _name];
	if (!([state.headCommandUUID isEqual: storeState.headCommandUUID]
		  && [state.currentCommandUUID isEqual: storeState.currentCommandUUID]))
	{
		NSLog(@"In-memory snapshot is stale");
		state = storeState;
	}
		
	// Set aCommand's parent pointer
	aCommand.parentUUID = state.currentCommandUUID;

	if (_coalescing)
	{
		if (_lastCoalescedCommandUUID != nil)
		{
			// Pop from the in-memory copy since we are about to pop from the SQL DB
			
			COCommandGroup *lastGroup = [self commandForUUID: _lastCoalescedCommandUUID];
			
			if (lastGroup != nil)
			{
				NSLog(@"Coalescing %@ and %@", lastGroup, aCommand);
				[self insertCommandsFromGroup: lastGroup atStartOfGroup: aCommand];

				aCommand.parentUUID = lastGroup.parentUUID;
			}
		}
		_lastCoalescedCommandUUID = aCommand.UUID;
	}
	
	COUndoTrackSerializedCommand *serialized = [aCommand serializedCommand];
	[_store addCommand: serialized];
	aCommand.sequenceNumber = serialized.sequenceNumber;
	
	// Write out the new store state
	
	COUndoTrackState *newStoreState = [COUndoTrackState new];
	newStoreState.trackName = _name;
	newStoreState.currentCommandUUID = aCommand.UUID;
	newStoreState.headCommandUUID = aCommand.UUID;
	
	[_store setTrackState: newStoreState];
	_trackStateForName[_name] = newStoreState;
	
	// Finally, update our commands array
	
	[self reloadNodesOnCurrentBranch];
	
	ETAssert([_store commitTransaction]);
	
	[self didUpdate];
}

-(void)clear
{
	[_store beginTransaction];
	[_store removeTrackWithName: _name];
	ETAssert([_store commitTransaction]);
	
	_nodesOnCurrentUndoBranch = nil;
	[_commandsByUUID removeAllObjects];
	[_trackStateForName removeAllObjects];
}

- (NSArray *) allCommands
{
	[self loadIfNeeded];
	
	return [_commandsByUUID allValues];
}

#pragma mark - Private

/**
 * Undo and redo the given commands, in order
 */
- (void) undo: (NSArray *)undo1 redo: (NSArray *)redo1 undo: (NSArray *)undo2 redo: (NSArray *)redo2
{
	ETAssert([undo1 count] == 0 || [redo1 count] == 0);
	ETAssert([undo2 count] == 0 || [redo2 count] == 0);
	
	for (COCommandGroup *cmd in undo1)
	{
		[self doCommand: cmd inverse: YES];
	}
	for (COCommandGroup *cmd in redo1)
	{
		[self doCommand: cmd inverse: NO];
	}
	for (COCommandGroup *cmd in undo2)
	{
		[self doCommand: cmd inverse: YES];
	}
	for (COCommandGroup *cmd in redo2)
	{
		[self doCommand: cmd inverse: NO];
	}
}

- (void) doCommand: (COCommandGroup *)aCommand inverse: (BOOL)inverse
{
	COCommandGroup *commandToApply = (inverse ? [aCommand inverse] : aCommand);
	[commandToApply applyToContext: _editingContext];
    
    // N.B. This must not automatically push a revision
    _editingContext.isRecordingUndo = NO;
	// TODO: If we can detect a non-selective undo and -commit returns a command,
	// we could implement -validateUndoCommitWithCommand: to ensure there is no
	// command COCommandCreatePersistentRoot or COCommandNewRevisionForBranch
	// that create new revisions in the store.
    [_editingContext commitWithIdentifier: inverse ?  @"org.etoile.CoreObject.undo" : @"org.etoile.CoreObject.redo"
						  metadata: [commandToApply localizedShortDescription] != nil
										? @{ kCOCommitMetadataShortDescriptionArguments : @[[commandToApply localizedShortDescription]] }
										: @{}
						 undoTrack: nil
							 error: NULL];
    _editingContext.isRecordingUndo = YES;
	
	// Update the current command for this track.

	NSString *trackName = aCommand.trackName;
	COUndoTrackState *currentTrackState = _trackStateForName[trackName];
	
	// FIgure out the new current and head UUIDS
	ETUUID *newCurrentNodeUUID = inverse ? aCommand.parentUUID : aCommand.UUID;
	ETUUID *newHeadNodeUUID = currentTrackState.headCommandUUID;
	
	// Write out the new store state
	
	COUndoTrackState *newStoreState = [COUndoTrackState new];
	newStoreState.trackName = trackName;
	newStoreState.currentCommandUUID = newCurrentNodeUUID;
	newStoreState.headCommandUUID = newHeadNodeUUID;
	
	[_store setTrackState: newStoreState];
	_trackStateForName[trackName] = newStoreState;
}

- (void) setParentPointersForCommandGroup: (COCommandGroup *)aCommand
{
	// FIXME: Assert that we are not a pattern track
	aCommand.trackName = _name;
	
	ETAssert(aCommand.parentUndoTrack == nil);
	for (COCommand *childCommand in aCommand.contents)
	{
		ETAssert(childCommand.parentUndoTrack == nil);
	}
	
	aCommand.parentUndoTrack = self;
	for (COCommand *childCommand in aCommand.contents)
	{
		childCommand.parentUndoTrack = self;
	}
	
	_commandsByUUID[aCommand.UUID] = aCommand;
}

- (COCommandGroup *) currentCommandGroup
{
	[self loadIfNeeded];
	
	NSMutableArray *potentialCurrentCommands = [NSMutableArray new];
	for (COUndoTrackState *state in [_trackStateForName allValues])
	{
		if (state.currentCommandUUID != nil)
		{
			[potentialCurrentCommands addObject: [self commandForUUID: state.currentCommandUUID]];
		}
	}

	COCommandGroup *commandWithMaxSequenceNumber = nil;
	int64_t max = -1;
	for (COCommandGroup *command in potentialCurrentCommands)
	{
		if (command.sequenceNumber > max)
		{
			commandWithMaxSequenceNumber = command;
			max = command.sequenceNumber;
		}
	}
	return commandWithMaxSequenceNumber;
}

- (void) reloadNodesOnCurrentBranch
{
	ETAssert(_nodesOnCurrentUndoBranch != nil);
	[_nodesOnCurrentUndoBranch removeAllObjects];
	
	// Populate _nodesOnCurrentUndoBranch, from the head backwards
	if ([_trackStateForName count] > 0)
	{
		for (COUndoTrackState *trackState in [_trackStateForName allValues])
		{
			ETUUID *commandUUID = trackState.headCommandUUID;
			while (commandUUID != nil)
			{
				COCommandGroup *command = [self commandForUUID: commandUUID];
				ETAssert([command.UUID isEqual: commandUUID]);
				
				[_nodesOnCurrentUndoBranch addObject: command];
				commandUUID = command.parentUUID;
			}
			
			// Also make sure all commands have been loaded, including divergent ones
			for (ETUUID *uuid in [_store allCommandUUIDsOnTrackWithName: _name])
			{
				[self commandForUUID: uuid];
			}
		}
		
		// Now, sort the nodes
		
		[_nodesOnCurrentUndoBranch sortUsingDescriptors:
		 @[[NSSortDescriptor sortDescriptorWithKey: @"sequenceNumber" ascending: YES]]];
	}
	[_nodesOnCurrentUndoBranch insertObject: [COEndOfUndoTrackPlaceholderNode sharedInstance] atIndex: 0];
}

- (void) reload
{
	_nodesOnCurrentUndoBranch = [NSMutableArray new];
	
	// May be empty if we are uncommitted
	NSArray *matchingNames = [_store trackNamesMatchingGlobPattern: _name];
	for (NSString *matchingName in matchingNames)
	{
		COUndoTrackState *trackState = [_store stateForTrackName: matchingName];
		_trackStateForName[matchingName] = trackState;
	}
	
	[self reloadNodesOnCurrentBranch];
}

- (void) loadIfNeeded
{
	if (_nodesOnCurrentUndoBranch == nil)
	{
		[self reload];
	}
}

/**
 * Returns a command from the _commandsByUUID, or loads it from the store if
 * it's not present
 */
- (COCommandGroup *) commandForUUID:(ETUUID *)aUUID
{
	COCommandGroup *command = _commandsByUUID[aUUID];
	if (command == nil)
	{
		COUndoTrackSerializedCommand *serializedCommand = [_store commandForUUID: aUUID];
		ETAssert([serializedCommand.UUID isEqual: aUUID]);
		command = [self loadSerializedCommand: serializedCommand];
		ETAssert([command.UUID isEqual: aUUID]);
	}
	return command;
}

- (COCommandGroup *) loadSerializedCommand: (COUndoTrackSerializedCommand *)serializedCommand
{
	COCommandGroup *command = [[COCommandGroup alloc] initWithSerializedCommand: serializedCommand
																		  owner: self];
	ETAssert([command.UUID isEqual: serializedCommand.UUID]);
	_commandsByUUID[serializedCommand.UUID] = command;
	return command;
}

#pragma mark - Convenience

- (NSString *) undoMenuItemTitle
{
	id<COTrackNode> node = [self currentNode];
	NSString *shortDescription;
	if (node == [COEndOfUndoTrackPlaceholderNode sharedInstance])
	{
		shortDescription = @"";
	}
	else
	{
		shortDescription = [node localizedShortDescription];
	}
	
	// TODO: Localize the "Undo" string
	return [NSString stringWithFormat: @"Undo %@", shortDescription];
}

- (NSString *) redoMenuItemTitle
{
	id<COTrackNode> node = [self nextNodeOnTrackFrom: [self currentNode] backwards: NO];
	NSString *shortDescription;
	if (node == nil)
	{
		shortDescription = @"";
	}
	else
	{
		shortDescription = [node localizedShortDescription];
	}
	
	// TODO: Localize the "Redo" string
	return [NSString stringWithFormat: @"Redo %@", shortDescription];
}

#pragma mark - Notification handling

- (void) storeTracksDidChange: (NSNotification *)notif
{
	NSArray *changedTracks = [notif userInfo][COUndoTrackStoreChangedTracks];
	// FIXME: Do fine-grained reloading only if needed
	
	[self reload];
}

- (void) postNotificationsForStackName: (NSString *)aStack
{
    NSDictionary *userInfo = @{kCOUndoStackName : aStack};
    
    [[NSNotificationCenter defaultCenter] postNotificationName: COUndoStackDidChangeNotification
                                                        object: self
                                                      userInfo: userInfo];
    
    //    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
    //                                                                   object: [[self UUID] stringValue]
    //                                                                 userInfo: userInfo
    //                                                       deliverImmediately: NO];
}


- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter]
	 postNotificationName: ETCollectionDidUpdateNotification object: self];
    [self postNotificationsForStackName: _name];
}

#pragma mark - Coalescing

- (void)beginCoalescing
{
	_coalescing = YES;
	_lastCoalescedCommandUUID = nil;
}

- (void)endCoalescing
{
	_coalescing = NO;
	_lastCoalescedCommandUUID = nil;
}

static BOOL coalesceOpPair(COCommand *op, COCommand *nextOp)
{
	if ([op isKindOfClass: [COCommandSetCurrentVersionForBranch class]]
		&& [nextOp isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
	{
		COCommandSetCurrentVersionForBranch *firstSetVersion = (COCommandSetCurrentVersionForBranch *)op;
		COCommandSetCurrentVersionForBranch *nextSetVersion = (COCommandSetCurrentVersionForBranch *)nextOp;
		
		if ([nextSetVersion.oldHeadRevisionUUID isEqual: firstSetVersion.headRevisionUUID]
			&& [nextSetVersion.oldRevisionUUID isEqual: firstSetVersion.revisionUUID])
		{
			firstSetVersion.headRevisionUUID = nextSetVersion.headRevisionUUID;
			firstSetVersion.revisionUUID = nextSetVersion.revisionUUID;
			return YES;
		}
	}
	return NO;
}

static void coalesceOpsInternal(NSMutableArray *ops, NSUInteger i)
{
	if (i+1 >= [ops count])
		return;
	
	if (coalesceOpPair(ops[i], ops[i+1]))
	{
		[ops removeObjectAtIndex: i+1];
		coalesceOpsInternal(ops, i);
	}
	else
	{
		return coalesceOpsInternal(ops, i+1);
	}
}

/**
 * This will collapse contiguous runs of COCommandSetCurrentVersionForBranch commands
 * whose old and new revisions match up. e.g.
 *
 *     @[<COCommandSetCurrentVersionForBranch r0 -> r1>, <COCommandSetCurrentVersionForBranch r1 -> r2>]
 *
 * gets collapsed to:
 *
 *     @[<COCommandSetCurrentVersionForBranch r0 -> r2>]
 */
static void coalesceOps(NSMutableArray *ops)
{
	coalesceOpsInternal(ops, 0);
}

- (void)insertCommandsFromGroup: (COCommandGroup *)source atStartOfGroup: (COCommandGroup *)dest
{
	NSMutableArray *newCommands = [NSMutableArray arrayWithArray: source.contents];
	[newCommands addObjectsFromArray: dest.contents];
	coalesceOps(newCommands);
	dest.contents = newCommands;
}

#pragma mark - ETCollection

- (BOOL)isOrdered
{
	return YES;
}

- (id)content
{
	return [self nodes];
}

- (NSArray *)contentArray
{
	return [NSArray arrayWithArray: [self nodes]];
}

@end


@implementation COPatternUndoTrack

- (void) recordCommand: (COCommand *)aCommand
{
    [NSException raise: NSGenericException
	            format: @"You can't push actions to a %@", [self className]];
}

@end
