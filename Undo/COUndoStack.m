#import <EtoileFoundation/EtoileFoundation.h>

#import "COUndoStackStore.h"
#import "COUndoStack.h"
#import "COEditingContext+Undo.h"
#import "COEditingContext+Private.h"
#import "COCommand.h"

NSString * const COUndoStackDidChangeNotification = @"COUndoStackDidChangeNotification";
NSString * const kCOUndoStackName = @"COUndoStackName";

@interface COUndoStack ()

@property (strong, readwrite, nonatomic) COUndoStackStore *store;
@property (strong, readwrite, nonatomic) NSString *name;

@end

@implementation COUndoStack

@synthesize name = _name, store = _store, editingContext = _editingContext;

+ (void) initialize
{
	if (self != [COUndoStack class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

- (id) initWithStore: (COUndoStackStore *)aStore name: (NSString *)aName
{
    SUPERINIT;
    self.name = aName;
    self.store = aStore;
    return self;
}

- (NSArray *) undoNodes
{
    return [_store stackContents: kCOUndoStack forName: _name];
}

- (NSArray *) redoNodes
{
    return [_store stackContents: kCORedoStack forName: _name];
}

- (BOOL) canUndoWithEditingContext: (COEditingContext *)aContext
{
    COCommand *edit = [self peekEditFromStack: kCOUndoStack forName: _name];
    return [self canApplyEdit: edit toContext: aContext];
}

- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext
{
    COCommand *edit = [self peekEditFromStack: kCORedoStack forName: _name];
    return [self canApplyEdit: edit toContext: aContext];
}

- (void) undoWithEditingContext: (COEditingContext *)aContext
{
    [self popAndApplyFromStack: kCOUndoStack pushToStack: kCORedoStack name: _name toContext: aContext];
}
- (void) redoWithEditingContext: (COEditingContext *)aContext
{
    [self popAndApplyFromStack: kCORedoStack pushToStack: kCOUndoStack name: _name toContext: aContext];
}

- (void) clear
{
    [_store clearStack: kCOUndoStack forName: _name];
    [_store clearStack: kCORedoStack forName: _name];
}


- (COCommand *) peekEditFromStack: (NSString *)aStack forName: (NSString *)aName
{
    id plist = [_store peekStack: aStack forName: aName];
    if (plist == nil)
    {
        return nil;
    }
    
    COCommand *edit = [COCommand commandWithPlist: plist];
    return edit;
}

- (BOOL) canApplyEdit: (COCommand*)anEdit toContext: (COEditingContext *)aContext
{
    if (anEdit == nil)
    {
        return NO;
    }
    
    return [anEdit canApplyToContext: aContext];
}

- (BOOL) popAndApplyFromStack: (NSString *)popStack
                  pushToStack: (NSString*)pushStack
                         name: (NSString *)aName
                    toContext: (COEditingContext *)aContext
{
    [_store beginTransaction];
    
    NSString *actualStackName = [_store peekStackName: popStack forName: aName];
	BOOL isUndo = [popStack isEqual: kCOUndoStack];
    COCommand *edit = [self peekEditFromStack: popStack forName: aName];
	COCommand *appliedEdit = (isUndo ? [edit inverse] : edit);

    if (![self canApplyEdit: appliedEdit toContext: aContext])
    {
        // DEBUG: Break here
        edit = [self peekEditFromStack: popStack forName: aName];
		appliedEdit =  (isUndo ? [edit inverse] : edit);
        [self canApplyEdit: appliedEdit toContext: aContext];
        
        [_store commitTransaction];
        [NSException raise: NSInvalidArgumentException format: @"Can't apply edit %@", edit];
    }
    
    // Pop from undo stack
    [_store popStack: popStack forName: aName];
    
    // Apply the edit
    [appliedEdit applyToContext: aContext];
    
    // N.B. This must not automatically push a revision
    aContext.isRecordingUndo = NO;
	// TODO: If we can detect a non-selective undo and -commit returns a command,
	// we could implement -validateUndoCommitWithCommand: to ensure there is no
	// command COCommandCreatePersistentRoot or COCommandNewRevisionForBranch
	// that create new revisions in the store.
    [aContext commit];
    aContext.isRecordingUndo = YES;
    
    [_store pushAction: [edit plist] stack: pushStack forName: actualStackName];
    
    return [_store commitTransaction];
}

- (void) recordCommandInverse: (COCommand *)aCommand
{
    id plist = [aCommand plist];
    //NSLog(@"Undo event: %@", plist);
    
    // N.B. The kCOUndoStack contains COCommands that are the inverse of
    // what the user did. So if the user creates a persistent root,
    // we push an edit to kCOUndoStack that deletes that persistent root.
    // => to perform an undo, pop from the kCOUndoStack and apply the edit.
    
    [_store pushAction: plist stack: kCOUndoStack forName: _name];
    
    [self postNotificationsForStackName: _name];
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
}

- (COCommand *)currentCommand
{
	return [self peekEditFromStack: kCOUndoStack forName: _name];
}

- (void)setCurrentCommand: (COCommand *)aCommand
{
	INVALIDARG_EXCEPTION_TEST(aCommand, [[self nodes] containsObject: aCommand]);

	// TODO: Write an optimized version. For store operation commands
	// (e.g. create branch etc.), just apply the inverse. For commit-based
	// commands, track the set revision per persistent root in the loop,
	// and just revert persistent roots to the collected revisions at exit time. 
	// The collected revisions follows or matches the current command.
	while ([[self currentCommand] isEqual: aCommand] == NO)
	{
    	[self popAndApplyFromStack: kCOUndoStack pushToStack: kCORedoStack name: _name toContext: [self editingContext]];
	}
}

- (void)reloadCommands
{
	_commands = [[NSMutableArray alloc] initWithCapacity: 5000];

	for (NSDictionary *plist in [_store stackContents: kCOUndoStack forName: _name])
	{
		[_commands addObject: [COCommand commandWithPlist: plist]];
	}

	// FIXME: Simplistic and invalid redo stack loading
	for (NSDictionary *plist in [_store stackContents: kCORedoStack forName: _name])
	{
		[_commands addObject: [COCommand commandWithPlist: plist]];
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
	return (id)[self currentCommand];
}

- (void)setCurrentNode: (id <COTrackNode>)node
{
	INVALIDARG_EXCEPTION_TEST(node, [node isKindOfClass: [COCommand class]]);
	[self setCurrentCommand: (COCommand *)node];
	[self didUpdate];
}

- (void)undoNode: (id <COTrackNode>)aNode
{
	// TODO: Implement Selective Undo
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

@end
