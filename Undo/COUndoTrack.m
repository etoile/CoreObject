/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>

#import "COUndoStackStore.h"
#import "COUndoTrack.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "COCommandGroup.h"
#import "COEndOfUndoTrackPlaceholderNode.h"
#import "COCommandSetCurrentVersionForBranch.h"

NSString * const COUndoStackDidChangeNotification = @"COUndoStackDidChangeNotification";
NSString * const kCOUndoStackName = @"COUndoStackName";

@interface COPatternUndoTrack : COUndoTrack
@end


@interface COUndoTrack ()
@property (strong, readwrite, nonatomic) COUndoStackStore *store;
@property (strong, readwrite, nonatomic) NSString *name;
@end

@implementation COUndoTrack

@synthesize name = _name, store = _store, editingContext = _editingContext;

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
	return [[self alloc] initWithStore: [COUndoStackStore defaultStore]
	                              name: aName
	                    editingContext: aContext];
}

+ (COUndoTrack *)trackForPattern: (NSString *)aPattern
              withEditingContext: (COEditingContext *)aContext
{
	return [[COPatternUndoTrack alloc] initWithStore: [COUndoStackStore defaultStore]
	                                            name: aPattern
	                                  editingContext: aContext];
}

- (id) initWithStore: (COUndoStackStore *)aStore
                name: (NSString *)aName
	  editingContext: (COEditingContext *)aContext
{
    SUPERINIT;
    _name = aName;
    _store = aStore;
	_editingContext = aContext;
    return self;
}

#pragma mark -
#pragma mark Undo and Redo

- (BOOL)canUndo
{
    COCommand *edit = [self peekEditFromStack: kCOUndoStack forName: _name];
	COCommand *inverse = [edit inverse];
    return [self canApplyEdit: inverse toContext: _editingContext];
}

- (BOOL)canRedo
{
    COCommand *edit = [self peekEditFromStack: kCORedoStack forName: _name];
    return [self canApplyEdit: edit toContext: _editingContext];
}

- (void)undo
{
    [self popAndApplyFromStack: kCOUndoStack pushToStack: kCORedoStack name: _name toContext: _editingContext];
	[self didUpdate];
}

- (void)redo
{
    [self popAndApplyFromStack: kCORedoStack pushToStack: kCOUndoStack name: _name toContext: _editingContext];
	[self didUpdate];
}

#pragma mark -
#pragma mark Managing Commands

- (void) clear
{
    [_store clearStack: kCOUndoStack forName: _name];
    [_store clearStack: kCORedoStack forName: _name];
	[_commands removeAllObjects];
}

- (COCommandGroup *) peekEditFromStack: (NSString *)aStack forName: (NSString *)aName
{
    id plist = [_store peekStack: aStack forName: aName];
    if (plist == nil)
    {
        return nil;
    }
    
    COCommandGroup *edit = (COCommandGroup *)[COCommand commandWithPropertyList: plist parentUndoTrack: self];
    return edit;
}

- (COCommandGroup *) popEditFromStack: (NSString *)aStack forName: (NSString *)aName
{
    COCommandGroup *result = [self peekEditFromStack: aStack forName: aName];
	[_store popStack: aStack forName: aName];
    return result;
}

- (BOOL) canApplyEdit: (COCommand*)anEdit toContext: (COEditingContext *)aContext
{
    if (anEdit == nil)
    {
        return NO;
    }
    
    return [anEdit canApplyToContext: aContext];
}

- (BOOL) popAndApplyCommand: (COCommandGroup *)edit
				  fromStack: (NSString *)popStack
				pushToStack: (NSString*)pushStack
					   name: (NSString *)aName
				  toContext: (COEditingContext *)aContext
{
    [_store beginTransaction];
    
	ETUUID *actionUUID = [edit UUID];
    NSString *actualStackName = [_store peekStackName: popStack forActionWithUUID: actionUUID forName: aName];
	BOOL isUndo = [popStack isEqual: kCOUndoStack];
	COCommandGroup *appliedEdit = (isUndo ? [edit inverse] : edit);
	appliedEdit.UUID = edit.UUID;
	
    if (![self canApplyEdit: appliedEdit toContext: aContext])
    {
		[_store commitTransaction];
        [NSException raise: NSInvalidArgumentException format: @"Can't apply edit %@", edit];
    }
    
    // Pop from undo track
    [_store popActionWithUUID: actionUUID stack: popStack forName: aName];
    
    // Apply the edit
    [appliedEdit applyToContext: aContext];
    
    // N.B. This must not automatically push a revision
    aContext.isRecordingUndo = NO;
	// TODO: If we can detect a non-selective undo and -commit returns a command,
	// we could implement -validateUndoCommitWithCommand: to ensure there is no
	// command COCommandCreatePersistentRoot or COCommandNewRevisionForBranch
	// that create new revisions in the store.
    [aContext commitWithIdentifier: isUndo ?  @"org.etoile.CoreObject.undo" : @"org.etoile.CoreObject.redo"
						  metadata: [edit localizedShortDescription] != nil ? @{ kCOCommitMetadataShortDescriptionArguments : @[[edit localizedShortDescription]] } : @{}
						 undoTrack: nil
							 error: NULL];
    aContext.isRecordingUndo = YES;
    
	COCommandGroup *rewrittenEdit = appliedEdit;// [appliedEdit rewrittenCommandAfterCommitInContext: aContext];
	
	COCommandGroup *editToPush = edit;//(isUndo ? [rewrittenEdit inverse] : rewrittenEdit);
	editToPush.UUID = rewrittenEdit.UUID;
    [_store pushAction: [editToPush propertyList] stack: pushStack forName: actualStackName];
    
    BOOL ok = [_store commitTransaction];
	[self reloadCommands];
	return ok;
}

- (BOOL) popAndApplyFromStack: (NSString *)popStack
                  pushToStack: (NSString*)pushStack
                         name: (NSString *)aName
                    toContext: (COEditingContext *)aContext
{
    COCommandGroup *edit = [self peekEditFromStack: popStack forName: aName];

	if (edit == nil)
	{
		NSLog(@"error");
		return NO;
	}
	
	return [self popAndApplyCommand: edit fromStack:popStack pushToStack:pushStack name:aName toContext:aContext];
}

- (void) setParentPointersForCommandGroup: (COCommandGroup *)aCommand
{
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
}

- (void) recordCommand: (COCommandGroup *)aCommand
{
	ETAssert([aCommand isKindOfClass: [COCommandGroup class]]);
	// TODO: A SQL constraint and batch UUID would prevent pushing a command twice more strictly.
	INVALIDARG_EXCEPTION_TEST(aCommand, [aCommand isEqual: [self currentCommand]] == NO);

	[self setParentPointersForCommandGroup: aCommand];
	[self discardRedoCommands];
	[self addNewUndoCommand: aCommand];
	[self didUpdate];
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

#pragma mark -
#pragma mark Track Protocol

- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: ETCollectionDidUpdateNotification object: self];
    [self postNotificationsForStackName: _name];
}

- (void)discardRedoCommands
{
	[_store clearStack: kCORedoStack forName: _name];

	if (_commands == nil)
		return;

	NSUInteger currentIndex = [_commands indexOfObject: [self currentNode]];
	[_commands removeObjectsFromIndex: currentIndex + 1];
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

- (void)addNewUndoCommand: (COCommandGroup *)newCommand
{
	[_store beginTransaction];
	if (_coalescing)
	{
		if (_lastCoalescedCommandUUID != nil)
		{
			// Pop from the in-memory copy since we are about to pop from the SQL DB
			if ([_commands count] > 0)
				[_commands removeLastObject];
			
			COCommandGroup *lastGroup = [self popEditFromStack: kCOUndoStack forName: _name];
					
			if (lastGroup != nil)
			{
				//NSLog(@"Coalescing %@ and %@", lastGroup, newCommand);
				[self insertCommandsFromGroup: lastGroup atStartOfGroup: newCommand];
			}
		}
		_lastCoalescedCommandUUID = newCommand.UUID;
	}
	
	[_store pushAction: [newCommand propertyList] stack: kCOUndoStack forName: _name];

	COCommand *currentCommand = [self currentCommand];
	NSParameterAssert([newCommand isEqual: currentCommand]);
	BOOL currentCommandUnchanged = [currentCommand isEqual: [_commands lastObject]];
	
	if (!currentCommandUnchanged && _commands != nil)
	{
		[_commands addObject: newCommand];
	}
	
	ETAssert([_store commitTransaction]);
}

- (COCommandGroup *)currentCommand
{
	return [self peekEditFromStack: kCOUndoStack forName: _name];
}

- (BOOL)setCurrentCommand: (COCommand *)aCommand
{
	INVALIDARG_EXCEPTION_TEST(aCommand, [[self nodes] containsObject: aCommand]);

	NSUInteger oldIndex = [[self nodes] indexOfObject: [self currentNode]];
	NSUInteger newIndex = [[self nodes] indexOfObject: aCommand];
	BOOL isUndo = (newIndex < oldIndex);
	BOOL isRedo = (newIndex > oldIndex);

	BOOL appliedAll = YES;
	
	if (isUndo)
	{
		// TODO: Write an optimized version. For store operation commands
		// (e.g. create branch etc.), just apply the inverse. For commit-based
		// commands, track the set revision per persistent root in the loop,
		// and just revert persistent roots to the collected revisions at exit time.
		// The collected revisions follows or matches the current command.
		while ([[self currentNode] isEqual: aCommand] == NO)
		{
			if (![self canUndo])
			{
				appliedAll = NO;
				break;
			}
			[self popAndApplyFromStack: kCOUndoStack pushToStack: kCORedoStack name: _name toContext: [self editingContext]];
		}
	}
	else if (isRedo)
	{
		// TODO: Write an optimized version (see above).
		while ([[self currentNode] isEqual: aCommand] == NO)
		{
			if (![self canRedo])
			{
				appliedAll = NO;
				break;
			}
			[self popAndApplyFromStack: kCORedoStack pushToStack: kCOUndoStack name: _name toContext: [self editingContext]];
		}
	}
	[self didUpdate];
	
	return appliedAll;
}

- (void)reloadCommands
{
	_commands = [[NSMutableArray alloc] initWithCapacity: 5000];

	[_commands addObject: [COEndOfUndoTrackPlaceholderNode sharedInstance]];
	
	for (NSDictionary *plist in [_store stackContents: kCOUndoStack forName: _name])
	{
		[_commands addObject: [COCommand commandWithPropertyList: plist parentUndoTrack: self]];
	}

	for (NSDictionary *plist in [[_store stackContents: kCORedoStack forName: _name] reverseObjectEnumerator])
	{
		[_commands addObject: [COCommand commandWithPropertyList: plist parentUndoTrack: self]];
	}
}

- (NSArray *)nodes
{
	if (_commands == nil)
	{
		[self reloadCommands];
	}
	return [_commands copy];
}

- (id)nextNodeOnTrackFrom: (id <COTrackNode>)aNode backwards: (BOOL)back
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

- (id <COTrackNode>)currentNode
{
	id <COTrackNode> command = [self currentCommand];
	if (command == nil)
	{
		command = [COEndOfUndoTrackPlaceholderNode sharedInstance];
	}
	return command;
}

- (BOOL)setCurrentNode: (id <COTrackNode>)node
{
	INVALIDARG_EXCEPTION_TEST(node, [node isKindOfClass: [COCommand class]]
							|| [node isKindOfClass: [COEndOfUndoTrackPlaceholderNode class]]);
	return [self setCurrentCommand: (COCommandGroup *)node];
}

- (void)undoNode: (id <COTrackNode>)aNode
{
	COUndoTrack *me = self; // FIXME: ARC hack
	
	INVALIDARG_EXCEPTION_TEST(aNode, [[self nodes] containsObject: aNode]);

    NSString *actualStackName = [_store peekStackName: kCOUndoStack forActionWithUUID: [aNode UUID] forName: _name];
	ETAssert(actualStackName != nil);
	COUndoTrack *track = [COUndoTrack trackForName: actualStackName withEditingContext: _editingContext];
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

	[self reloadCommands];
	[self didUpdate];
	
	NSLog(@"%@", me); // FIXME: ARC hack
}

- (void)redoNode: (id <COTrackNode>)aNode
{
}

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

@end


@implementation COPatternUndoTrack

- (void) recordCommand: (COCommand *)aCommand
{
    [NSException raise: NSGenericException
	            format: @"You can't push actions to a %@", [self className]];
}

@end

