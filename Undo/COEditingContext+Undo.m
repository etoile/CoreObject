#import "COEditingContext+Undo.h"
#import "COUndoStackStore.h"
#import "COEdit.h"
#import "COEditGroup.h"
#import <EtoileFoundation/Macros.h>


@implementation COEditingContext (Undo)

- (COEdit *) peekEditFromStack: (NSString *)aStack forName: (NSString *)aName
{
    id plist = [_undoStackStore peekStack: aStack forName: aName];
    if (plist == nil)
    {
        return nil;
    }
    
    COEdit *edit = [COEdit editWithPlist: plist];
    return edit;
}

- (BOOL) canApplyEdit: (COEdit*)anEdit
{
    if (anEdit == nil)
    {
        return NO;
    }
    
    return [anEdit canApplyToContext: self];
}

// Public API

- (BOOL) canUndoForStackNamed: (NSString *)aName
{
    COEdit *edit = [self peekEditFromStack: kCOUndoStack forName: aName];
    COEdit *inverse = [edit inverse];
    return [self canApplyEdit: inverse];
}

- (BOOL) canRedoForStackNamed: (NSString *)aName
{
    COEdit *edit = [self peekEditFromStack: kCOUndoStack forName: aName];
    COEdit *inverse = [edit inverse];
    return [self canApplyEdit: inverse];
}

- (BOOL) undoForStackNamed: (NSString *)aName
{
    [_undoStackStore beginTransaction];
    
    COEdit *edit = [self peekEditFromStack: kCOUndoStack forName: aName];
    if (![self canApplyEdit: edit])
    {
        [_undoStackStore commitTransaction];
        [NSException raise: NSInvalidArgumentException format: @"Can't apply edit %@", edit];
    }
    
    // Pop from undo stack, push the inverse onto the redo stack.
    
    [_undoStackStore popStack: kCOUndoStack forName: aName];
    
    COEdit *inverse = [edit inverse];
    [inverse applyToContext: self];
    
    // N.B. This must not automatically push a revision
    [self commit];
    
    [_undoStackStore pushAction: [inverse plist] stack: kCORedoStack forName: aName];

    return [_undoStackStore commitTransaction];
}

- (BOOL) redoForStackNamed: (NSString *)aName
{
    // Same as above but swap undo and redo
}

- (BOOL) commitWithStackNamed: (NSString *)aName
{
    // Version of commit that automatically pushes a COEditGroup of the edits made
}

// Methods called during commit

// Called from COEditingContext

- (void) recordBeginUndoGroup
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (_isRecordingUndo)
    {
        ASSIGN(_currentEditGroup, [[[COEditGroup alloc] init] autorelease]);
    }
    else
    {
        DESTROY(_currentEditGroup);
    }
}
- (void) recordEndUndoGroup
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void) recordPersistentRootDeletion: (COPersistentRoot *)aPersistentRoot
{
    NSLog(@"%@", NSStringFromSelector(_cmd)); 
}
- (void) recordPersistentRootUndeletion: (COPersistentRoot *)aPersistentRoot
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

// Called from COPersistentRoot

- (void) recordPersistentRootCreation: (COPersistentRootInfo *)info
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void) recordPersistentRoot: (COPersistentRoot *)aPersistentRoot
             setCurrentBranch: (COBranch *)aBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

// Called from COBranch

- (void) recordBranchCreation: (COBranch *)aBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void) recordBranchSetCurrentRevision: (COBranch *)aBranch
                          oldRevisionID: (CORevisionID *)aRevisionID
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void) recordBranchSetMetadata: (COBranch *)aBranch
                     oldMetadata: (id)oldMetadata
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void) recordBranchDeletion: (COBranch *)aBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void) recordBranchUndeletion: (COBranch *)aBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

@end
