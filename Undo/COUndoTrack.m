/*
	Copyright (C) 2014 Eric Wasylishen, Quentin Mathe

	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>

#import "COUndoTrackStore.h"
#import "COUndoTrackStore+Private.h"
#import "COUndoTrack.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "COCommandGroup.h"
#import "COEndOfUndoTrackPlaceholderNode.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COStoreTransaction.h"
#import "COPersistentRoot+Private.h"

extern NSString * const kCOCommandUUID;

NSString * const COUndoTrackDidChangeNotification = @"COUndoTrackDidChangeNotification";
NSString * const kCOUndoTrackName = @"COUndoTrackName";

@interface COPatternUndoTrack : COUndoTrack
@end


@interface COUndoTrack ()
@property (strong, readwrite, nonatomic) NSString *name;
@end

@implementation COUndoTrack

@synthesize name = _name, editingContext = _editingContext;
@synthesize customRevisionMetadata;

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
	return [[self alloc] initWithName: aName editingContext: aContext];
}

+ (COUndoTrack *)trackForPattern: (NSString *)aPattern
              withEditingContext: (COEditingContext *)aContext
{
	return [[COPatternUndoTrack alloc] initWithName: aPattern
	                                 editingContext: aContext];
}

- (id) initWithName: (NSString *)aName
     editingContext: (COEditingContext *)aContext
{
    SUPERINIT;
    _name = aName;
	_editingContext = aContext;
	_trackStateForName = [NSMutableDictionary new];
	_commandsByUUID = [NSMutableDictionary new];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storeTrackDidChange:)
                                                 name: COUndoTrackStoreTrackDidChangeNotification
                                               object: self.store];
	
    return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (COUndoTrackStore *)store
{
	return _editingContext.undoTrackStore;
}

#pragma mark - Track Protocol - Convenience Methods

- (BOOL)canUndo
{
	return [[self currentNode] parentNode] != nil;
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
	[self endCoalescing];
	const NSUInteger currentIndex = [_nodesOnCurrentUndoBranch indexOfObject: [self currentNode]];
	const NSUInteger targetIndex = [_nodesOnCurrentUndoBranch indexOfObject: node];
	
	ETAssert(currentIndex != NSNotFound);
	
	if (targetIndex == NSNotFound)
	{
		// Handle the more complex case of navigating to a node that isn't in _nodesOnCurrentUndoBranch
		return [self setCurrentNodeToDivergentNode: node];
	}

	// From now on, we're handling the simple case of navigating to another node
	// in the _nodesOnCurrentUndoBranch array.
	
	if (targetIndex == currentIndex)
		return YES;
	
	[self.store beginTransaction];
	
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
	
	BOOL ok = [self.store commitTransaction];
	if (ok)
	{
		if ([self isKindOfClass: [COPatternUndoTrack class]])
		{
			/* When the current command changes, the commands can be reordered
			   in a pattern track, due to the split between redo and undo nodes.

			   Track X -> A
			   Track Y -> B C
			   Pattern track X + Y -> A B C
			 
			   If we undo C, then we commit a change D on track X, the pattern 
			   track nodes are A B D C.
			   If we redo on the pattern track, without reloading the pattern
			   track nodes would remain A B D C and the current node stuck on D 
			   since -currentCommandGroup returns the most recent current 
			   command between X and Y (D sequence number is higher than C). 
			   
			   Reloading will reorder the pattern track to A B C D. */
			[self reloadNodesOnCurrentBranch];
		}
		else
		{
			[self didUpdate];
		}
	}
	return ok;
}

- (NSArray *) nodesFromNode: (id <COTrackNode>)node toTargetNode: (id <COTrackNode>)targetNode
{
	NSMutableArray *result = [NSMutableArray new];
	for (id <COTrackNode> temp = targetNode; temp != nil; temp = [temp parentNode])
	{
		if ([temp isEqual: node])
		{
			return result;
		}

		[result insertObject: temp atIndex: 0];
	}
	
	[NSException raise: NSGenericException format: @"Didn't find target node"];
	return nil;
}

- (BOOL)setCurrentNodeToDivergentNode: (id <COTrackNode>)node
{
	NILARG_EXCEPTION_TEST(node);
	ETAssert(![_nodesOnCurrentUndoBranch containsObject: node]);
	ETAssert(![node isEqual: [self currentNode]]);
	
	id<COTrackNode> commonAncestor = [self commonAncestorForNode: [self currentNode]
														 andNode: node];
	
	const NSUInteger commonAncestorIndex = [_nodesOnCurrentUndoBranch indexOfObject: commonAncestor];
	const NSUInteger currentIndex = [_nodesOnCurrentUndoBranch indexOfObject: [self currentNode]];
	ETAssert(commonAncestorIndex != NSNotFound);
	ETAssert(currentIndex != NSNotFound);

	[self.store beginTransaction];
	
	NSMutableArray *undo1 = [NSMutableArray new];
	NSMutableArray *redo1 = [NSMutableArray new];
	
	if (commonAncestorIndex < currentIndex)
	{
		for (NSUInteger i = currentIndex; i > commonAncestorIndex; i--)
		{
			[undo1 addObject: _nodesOnCurrentUndoBranch[i]];
		}
	}
	else if (commonAncestorIndex > currentIndex)
	{
		for (NSUInteger i = currentIndex + 1; i <= commonAncestorIndex; i++)
		{
			[redo1 addObject: _nodesOnCurrentUndoBranch[i]];
		}
	}
	
	// Now we are at commonAncestorIndex.
	
	NSArray *redo2 = [self nodesFromNode: commonAncestor toTargetNode: node];
	
	[self undo: undo1 redo: redo1 undo: @[] redo: redo2];
	
	BOOL ok = [self.store commitTransaction];
	if (ok)
	{
		/* When we set the current command to a divergent one, we switch to
		   another command branch (the head command changes) */
		[self reloadNodesOnCurrentBranch];
	}
	return ok;
}

- (void)undoNode: (id <COTrackNode>)aNode
{
	INVALIDARG_EXCEPTION_TEST(aNode, [aNode isKindOfClass: [COCommandGroup class]]);
	// NOTE: COCommand(Group).parentUndoTrack.name could be validated against
	// the receiver name with -[COUndoTrackStore string:matchesGlobPattern:].
	INVALIDARG_EXCEPTION_TEST(aNode, [((COCommandGroup *)aNode).trackName isEqual: self.name]);

	COCommandGroup *command = [(COCommandGroup *)aNode inverse];
	[command applyToContext: _editingContext];
	
	NSMutableDictionary *md = [aNode.metadata mutableCopy];
	NSNumber *inversedValue = aNode.metadata[kCOCommitMetadataUndoInitialBaseInversed];
	BOOL inversed = inversedValue == nil || !inversedValue.boolValue;

	md[kCOCommitMetadataUndoBaseUUID] = [aNode.UUID stringValue];
	md[kCOCommitMetadataUndoType] = @"org.etoile.CoreObject.selective-undo";
	md[kCOCommitMetadataUndoInitialBaseInversed] = @(inversed);

	if (self.customRevisionMetadata != nil)
	{
		[md addEntriesFromDictionary: self.customRevisionMetadata];
	}
	
	[_editingContext commitWithMetadata: md
	                          undoTrack: self
	                              error: NULL];
}

- (void)redoNode: (id <COTrackNode>)aNode
{
	INVALIDARG_EXCEPTION_TEST(aNode, [aNode isKindOfClass: [COCommandGroup class]]);
	INVALIDARG_EXCEPTION_TEST(aNode, [((COCommandGroup *)aNode).trackName isEqual: self.name]);

	COCommand *command = (COCommand *)aNode;
	[command applyToContext: _editingContext];
	
	NSMutableDictionary *md = [aNode.metadata mutableCopy];

	md[kCOCommitMetadataUndoBaseUUID] = [aNode.UUID stringValue];
	md[kCOCommitMetadataUndoType] = @"org.etoile.CoreObject.selective-redo";

	if (self.customRevisionMetadata != nil)
	{
		[md addEntriesFromDictionary: self.customRevisionMetadata];
	}
	
	[_editingContext commitWithMetadata: md
	                          undoTrack: self
	                              error: NULL];
}

#pragma mark - COUndoTrack - Other Public Methods

- (void) recordCommand: (COCommandGroup *)aCommand
{
	ETAssert([aCommand isKindOfClass: [COCommandGroup class]]);

	ETAssert([_trackStateForName count] <= 1);
	COUndoTrackState *state = _trackStateForName[_name];
	
	// Set ownership pointers (not parent UUID!)
	[self setParentPointersForCommandGroup: aCommand];

	[self.store beginTransaction];
	
	[self loadIfNeeded];
	
	// Check our state
	COUndoTrackState *storeState = [self.store stateForTrackName: _name];
	if (!([state.headCommandUUID isEqual: storeState.headCommandUUID]
		  && [state.currentCommandUUID isEqual: storeState.currentCommandUUID]))
	{
		NSLog(@"In-memory snapshot is stale");
		state = storeState;
	}
		
	// Set aCommand's parent pointer
	if (state.currentCommandUUID == nil)
	{
		aCommand.parentUUID = [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID];
	}
	else
	{
		aCommand.parentUUID = state.currentCommandUUID;
	}

	ETUUID *coalescedCommandUUIDToDelete = nil;
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
				coalescedCommandUUIDToDelete = _lastCoalescedCommandUUID;
			}
		}
		_lastCoalescedCommandUUID = aCommand.UUID;
	}
	
	COUndoTrackSerializedCommand *serialized = [aCommand serializedCommand];
	[self.store addCommand: serialized];
	aCommand.sequenceNumber = serialized.sequenceNumber;
	
	// Write out the new store state
	
	COUndoTrackState *newStoreState = [COUndoTrackState new];
	newStoreState.trackName = _name;
	newStoreState.currentCommandUUID = aCommand.UUID;
	newStoreState.headCommandUUID = aCommand.UUID;
	
	[self.store setTrackState: newStoreState];
	_trackStateForName[_name] = newStoreState;
	
	// Delete the obsolete last command created by coalescing
	if (coalescedCommandUUIDToDelete != nil)
	{
		[self.store removeCommandForUUID: coalescedCommandUUIDToDelete];
		[_commandsByUUID removeObjectForKey: coalescedCommandUUIDToDelete];
	}

	ETAssert([self.store commitTransaction]);
	[self reloadNodesOnCurrentBranch];
}

-(void)clear
{
	[self.store beginTransaction];
	[self.store removeTrackWithName: _name];
	ETAssert([self.store commitTransaction]);
	
	_nodesOnCurrentUndoBranch = nil;
	[_commandsByUUID removeAllObjects];
	[_trackStateForName removeAllObjects];
}

- (NSArray *) allCommands
{
	[self loadIfNeeded];
	
	NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey: @"sequenceNumber"
	                                                             ascending: YES];
	return [[_commandsByUUID allValues] sortedArrayUsingDescriptors: @[descriptor]];
}

- (NSArray *) childrenOfNode: (id<COTrackNode>)aNode
{
	// TODO: Precompute this and cache in a dictionary?
	
	NSMutableArray *result = [NSMutableArray new];
	for (COCommandGroup *command in [self allCommands])
	{
		if (aNode == [COEndOfUndoTrackPlaceholderNode sharedInstance])
		{
			if (command.parentUUID == nil)
				[result addObject: command];
		}
		else
		{
			if ([command.parentUUID isEqual: [aNode UUID]])
				[result addObject: command];
		}
	}
	return result;
}

#pragma mark - Private

- (BOOL) isCommandUUID: (ETUUID *)commitA equalToOrParentOfCommandUUID: (ETUUID *)commitB
{
    ETUUID *rev = commitB;
    while (rev != nil)
    {
        if ([rev isEqual: commitA])
        {
            return YES;
        }
        rev = [[self commandForUUID: rev] parentUUID];
		if ([rev isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]])
			rev = nil;
    }
    return NO;
}

- (id<COTrackNode>) commonAncestorForNode: (id<COTrackNode>)commitA andNode: (id<COTrackNode>)commitB
{
	NSMutableSet *ancestorUUIDsOfA = [NSMutableSet set];
	
	for (id<COTrackNode> temp = commitA; temp != nil; temp = [temp parentNode])
	{
		[ancestorUUIDsOfA addObject: temp.UUID];
	}

	if ([[self nodes].firstObject isEqual: [COEndOfUndoTrackPlaceholderNode sharedInstance]])
	{
		ETAssert([ancestorUUIDsOfA containsObject: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
	}

	for (id<COTrackNode> temp = commitB; temp != nil; temp = [temp parentNode])
	{
		if ([ancestorUUIDsOfA containsObject: temp.UUID])
		{
			return temp;
		}
	}
	
	ETAssertUnreachable();
	return nil;
}

/**
 * Undo and redo the given commands, in order
 */
- (void) undo: (NSArray *)undo1 redo: (NSArray *)redo1 undo: (NSArray *)undo2 redo: (NSArray *)redo2
{
	ETAssert([undo1 count] == 0 || [redo1 count] == 0);
	ETAssert([undo2 count] == 0 || [redo2 count] == 0);
	
	COStoreTransaction *txn = [COStoreTransaction new];
	
	for (COCommandGroup *cmd in undo1)
	{
		[self doCommand: cmd inverse: YES addToStoreTransaction: txn];
	}
	for (COCommandGroup *cmd in redo1)
	{
		[self doCommand: cmd inverse: NO addToStoreTransaction: txn];
	}
	for (COCommandGroup *cmd in undo2)
	{
		[self doCommand: cmd inverse: YES addToStoreTransaction: txn];
	}
	for (COCommandGroup *cmd in redo2)
	{
		[self doCommand: cmd inverse: NO addToStoreTransaction: txn];
	}
	
	[self commitStoreTransaction: txn];
}

- (void) commitStoreTransaction: (COStoreTransaction *)txn
{
	// Set the last transaction IDs so the store will accept our transaction
	for (ETUUID *uuid in [txn persistentRootUUIDs])
	{
		COPersistentRoot *proot = [_editingContext persistentRootForUUID: uuid];
		[txn setOldTransactionID: proot.lastTransactionID forPersistentRoot: uuid];
		
		// N.B.: We DO NOT MODIFY proot's lastTransactionID property here, because the
		// in-memory state is out of date with respect to the store, and we need the
		// notification mechanism to refresh the in-memory state
	}
	
	BOOL ok = [[_editingContext store] commitStoreTransaction: txn];
	ETAssert(ok);
}

- (void) doCommand: (COCommandGroup *)aCommand inverse: (BOOL)inverse addToStoreTransaction: (COStoreTransaction *)txn
{
	COCommandGroup *commandToApply = (inverse ? [aCommand inverse] : aCommand);
	[commandToApply setParentUndoTrack: self];

	NSMutableDictionary *md = [aCommand.metadata mutableCopy];
	NSNumber *inversedValue = aCommand.metadata[kCOCommitMetadataUndoInitialBaseInversed];
	BOOL inversed = inverse && (inversedValue == nil || !inversedValue.boolValue);

	md[kCOCommitMetadataUndoBaseUUID] = [aCommand.UUID stringValue];
	md[kCOCommitMetadataUndoType] = inverse ? @"org.etoile.CoreObject.undo" : @"org.etoile.CoreObject.redo";
	md[kCOCommitMetadataUndoInitialBaseInversed] = @(inversed);

	if (self.customRevisionMetadata != nil)
	{
		[md addEntriesFromDictionary: self.customRevisionMetadata];
	}
	
	[commandToApply addToStoreTransaction: txn withRevisionMetadata: md assumingEditingContextState: _editingContext];
	
	// Update the current command for this track.

	NSString *trackName = aCommand.trackName;
	COUndoTrackState *currentTrackState = _trackStateForName[trackName];
	
	// FIgure out the new current and head UUIDS
	ETUUID *newCurrentNodeUUID = inverse ? aCommand.parentUUID : aCommand.UUID;
	if ([newCurrentNodeUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]])
		newCurrentNodeUUID = nil;
	
	ETUUID *newHeadNodeUUID;
	if (newCurrentNodeUUID == nil
		|| [self isCommandUUID: newCurrentNodeUUID equalToOrParentOfCommandUUID: currentTrackState.headCommandUUID])
	{
		newHeadNodeUUID = currentTrackState.headCommandUUID;
	}
	else
	{
		newHeadNodeUUID = newCurrentNodeUUID;
	}
	
	// Write out the new store state
	
	COUndoTrackState *newStoreState = [COUndoTrackState new];
	newStoreState.trackName = trackName;
	newStoreState.currentCommandUUID = newCurrentNodeUUID;
	newStoreState.headCommandUUID = newHeadNodeUUID;
	
	[self.store setTrackState: newStoreState];
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
			COCommandGroup *command = [self commandForUUID: state.currentCommandUUID];
			/* If after a compaction, we undo until we reach the placeholder node,
			   the current command UUID corresponds to a non-existent command.
			   This state was recreated by inversing the child command. 
			   For now, we don't reset the oldest command parent UUID to nil 
			   on compaction. We could do this too, although keeping the parent 
			   UUID easily tells us whether the track has been compacted or not. */
			BOOL wasDeleted = (command == nil);

			if (wasDeleted)
				continue;

			[potentialCurrentCommands addObject: command];
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
		NSMutableArray *undoNodes = [NSMutableArray new];
		NSMutableArray *redoNodes = [NSMutableArray new];
		BOOL isCompacted = NO;
		
		for (COUndoTrackState *trackState in [_trackStateForName allValues])
		{
			NSMutableArray *targetArray = redoNodes;
			ETUUID *commandUUID = trackState.headCommandUUID;

			while (commandUUID != nil && ![commandUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]])
			{
				if ([commandUUID isEqual: trackState.currentCommandUUID])
					targetArray = undoNodes;
				
				COCommandGroup *command = [self commandForUUID: commandUUID];
				BOOL isDeletedCommand = (command == nil);
	
				if (isDeletedCommand)
				{
					isCompacted = YES;
					break;
				}

				ETAssert([command.UUID isEqual: commandUUID]);
				
				[targetArray addObject: command];
				commandUUID = command.parentUUID;
			}
			
			// Also make sure all commands have been loaded, including divergent ones
			for (ETUUID *uuid in [self.store allCommandUUIDsOnTrackWithName: _name])
			{
				[self commandForUUID: uuid];
			}
		}
		
		// Now, sort the nodes
		
		[undoNodes sortUsingDescriptors:
		 @[[NSSortDescriptor sortDescriptorWithKey: @"sequenceNumber" ascending: YES]]];
		
		[redoNodes sortUsingDescriptors:
		 @[[NSSortDescriptor sortDescriptorWithKey: @"sequenceNumber" ascending: YES]]];
		
		if (!isCompacted)
		{
			[_nodesOnCurrentUndoBranch addObject: [COEndOfUndoTrackPlaceholderNode sharedInstance]];
		}
		[_nodesOnCurrentUndoBranch addObjectsFromArray: undoNodes];
		[_nodesOnCurrentUndoBranch addObjectsFromArray: redoNodes];
	}
	else
	{
		[_nodesOnCurrentUndoBranch setArray: @[[COEndOfUndoTrackPlaceholderNode sharedInstance]]];
	}
	[self didUpdate];
}

- (void) reload
{
	_nodesOnCurrentUndoBranch = [NSMutableArray new];
	
	// May be empty if we are uncommitted
	NSArray *matchingNames = [self.store trackNamesMatchingGlobPattern: _name];
	for (NSString *matchingName in matchingNames)
	{
		COUndoTrackState *trackState = [self.store stateForTrackName: matchingName];
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
	NILARG_EXCEPTION_TEST(aUUID);
	ETAssert(![aUUID isEqual: [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID]]);
	
	COCommandGroup *command = _commandsByUUID[aUUID];
	if (command == nil)
	{
		COUndoTrackSerializedCommand *serializedCommand = [self.store commandForUUID: aUUID];
		BOOL isDeletedCommand = (serializedCommand == nil);

		if (isDeletedCommand)
			return nil;

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

- (void) storeTrackDidChange: (NSNotification *)notif
{
	NSDictionary *userInfo = [notif userInfo];
	COUndoTrackState *notifState = [COUndoTrackState new];
	notifState.trackName = userInfo[COUndoTrackStoreTrackName];
	notifState.headCommandUUID = [ETUUID UUIDWithString: userInfo[COUndoTrackStoreTrackHeadCommandUUID]];
	if (userInfo[COUndoTrackStoreTrackCurrentCommandUUID] != nil)
	{
		notifState.currentCommandUUID = [ETUUID UUIDWithString: userInfo[COUndoTrackStoreTrackCurrentCommandUUID]];
	}
	notifState.compacted = [userInfo[COUndoTrackStoreTrackCompacted] boolValue];

	if ([self.store string: notifState.trackName matchesGlobPattern: _name])
	{
		COUndoTrackState *inMemoryState = _trackStateForName[notifState.trackName];
		if (![inMemoryState isEqual: notifState])
		{
			//NSLog(@"Doing track reload");
			BOOL needsClearCommandCache = notifState.compacted;

			if (needsClearCommandCache)
			{
				[_commandsByUUID removeAllObjects];
			}
			[self reload];
		}
		else
		{
			//NSLog(@"Skipping track reload");
		}
	}
}

- (void) postNotificationsForTrackName: (NSString *)aTrack
{
    NSDictionary *userInfo = @{kCOUndoTrackName : aTrack};
	ETAssert([NSPropertyListSerialization propertyList: userInfo
	                                  isValidForFormat: NSPropertyListXMLFormat_v1_0]);

    [[NSNotificationCenter defaultCenter] postNotificationName: COUndoTrackDidChangeNotification
                                                        object: self
                                                      userInfo: userInfo];
    // FIXME: Implement distributed notification support
    //    [[NSDistributedNotificationCenter defaultCenter] postNotificationName: COStorePersistentRootDidChangeNotification
    //                                                                   object: [[self UUID] stringValue]
    //                                                                 userInfo: userInfo
    //                                                       deliverImmediately: NO];
}


- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter]
	 postNotificationName: ETCollectionDidUpdateNotification object: self];
    [self postNotificationsForTrackName: _name];
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

- (BOOL)isCoalescing
{
	return _coalescing;
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

- (void)undoNode: (id <COTrackNode>)aNode
{
	COUndoTrack *track = [COUndoTrack trackForName: ((COCommandGroup *)aNode).trackName
	                            withEditingContext: self.editingContext];
	ETAssert(track != nil);
	track.customRevisionMetadata = self.customRevisionMetadata;
	[track undoNode: aNode];
}

- (void)redoNode: (id <COTrackNode>)aNode
{
	COUndoTrack *track = [COUndoTrack trackForName: ((COCommandGroup *)aNode).trackName
	                            withEditingContext: self.editingContext];
	ETAssert(track != nil);
	track.customRevisionMetadata = self.customRevisionMetadata;
	[track redoNode: aNode];
}

- (void) recordCommand: (COCommand *)aCommand
{
    [NSException raise: NSGenericException
	            format: @"You can't push actions to a %@", [self className]];
}

@end
