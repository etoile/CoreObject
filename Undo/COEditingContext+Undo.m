#import "COEditingContext+Undo.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"
#import "COUndoStackStore.h"
#import "COCommand.h"
#import "COCommandGroup.h"
#import <EtoileFoundation/Macros.h>

#import "COCommandGroup.h"
#import "COCommandDeleteBranch.h"
#import "COCommandUndeleteBranch.h"
#import "COCommandSetBranchMetadata.h"
#import "COCommandSetCurrentBranch.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandDeletePersistentRoot.h"
#import "COCommandUndeletePersistentRoot.h"

@implementation COEditingContext (Undo)

- (COCommand *) peekEditFromStack: (NSString *)aStack forName: (NSString *)aName
{
    id plist = [_undoStackStore peekStack: aStack forName: aName];
    if (plist == nil)
    {
        return nil;
    }
    
    COCommand *edit = [COCommand commandWithPlist: plist];
    return edit;
}

- (BOOL) canApplyEdit: (COCommand*)anEdit
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
    COCommand *edit = [self peekEditFromStack: kCOUndoStack forName: aName];
    return [self canApplyEdit: edit];
}

- (BOOL) canRedoForStackNamed: (NSString *)aName
{
    COCommand *edit = [self peekEditFromStack: kCORedoStack forName: aName];
    return [self canApplyEdit: edit];
}

- (BOOL) popAndApplyFromStack: (NSString *)popStack pushToStack: (NSString*)pushStack name: (NSString *)aName
{
    [_undoStackStore beginTransaction];
    
    COCommand *edit = [self peekEditFromStack: popStack forName: aName];
    if (![self canApplyEdit: edit])
    {
        // DEBUG: Break here
        edit = [self peekEditFromStack: popStack forName: aName];
        [self canApplyEdit: edit];
        
        [_undoStackStore commitTransaction];
        [NSException raise: NSInvalidArgumentException format: @"Can't apply edit %@", edit];
    }
    
    // Pop from undo stack    
    [_undoStackStore popStack: popStack forName: aName];
    
    // Apply the edit    
    [edit applyToContext: self];
    
    // N.B. This must not automatically push a revision
    _isRecordingUndo = NO;
    [self commit];
    _isRecordingUndo = YES;

    // Push the inverse onto the redo stack    
    COCommand *inverse = [edit inverse];

    [_undoStackStore pushAction: [inverse plist] stack: pushStack forName: aName];

    return [_undoStackStore commitTransaction];
}

- (BOOL) undoForStackNamed: (NSString *)aName
{
    return [self popAndApplyFromStack: kCOUndoStack pushToStack: kCORedoStack name: aName];
}

- (BOOL) redoForStackNamed: (NSString *)aName
{
    return [self popAndApplyFromStack: kCORedoStack pushToStack: kCOUndoStack name: aName];
}

- (BOOL) commitWithStackNamed: (NSString *)aName
{
    self.undoStackName = aName;
    [self commit];
    return YES;
}

// Methods called during commit

// Called from COEditingContext

- (void) recordBeginUndoGroup
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (_isRecordingUndo)
    {
        ASSIGN(_currentEditGroup, [[[COCommandGroup alloc] init] autorelease]);
    }
    else
    {
        DESTROY(_currentEditGroup);
    }
}
- (void) recordEndUndoGroup
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    if (_isRecordingUndo)
    {
        if ([_currentEditGroup.contents isEmpty])
        {
            NSLog(@"-recordEndUndoGroup contents is empty!");
            DESTROY(_currentEditGroup);
            return;
        }

        // Optimisation: collapse COCommandGroups that contain only one child
        COCommand *objectToSerialize =
            (1 == [_currentEditGroup.contents count])
            ? [_currentEditGroup.contents firstObject]
            : _currentEditGroup;
        
        id plist = [objectToSerialize plist];        
        //NSLog(@"Undo event: %@", plist);
        
        // N.B. The kCOUndoStack contains COCommands that are the inverse of
        // what the user did. So if the user creates a persistent root,
        // we push an edit to kCOUndoStack that deletes that persistent root.
        // => to perform an undo, pop from the kCOUndoStack and apply the edit.
        
        if (self.undoStackName != nil)
        {
            [_undoStackStore pushAction: plist stack: kCOUndoStack forName: self.undoStackName];
        }
        
        DESTROY(_currentEditGroup);
    }
}

- (void) recordEditInverse: (COCommand*)anInverse
{
    // Insert the inverses back to front, so the inverse of the most recent action will be first.
    [_currentEditGroup.contents insertObject: anInverse atIndex: 0];
}

// Called from COEditingContext

- (void) recordPersistentRootDeletion: (COPersistentRoot *)aPersistentRoot
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COCommandUndeletePersistentRoot *edit = [[[COCommandUndeletePersistentRoot alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    [self recordEditInverse: edit];
}
- (void) recordPersistentRootUndeletion: (COPersistentRoot *)aPersistentRoot
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandDeletePersistentRoot *edit = [[[COCommandDeletePersistentRoot alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    [self recordEditInverse: edit];
}

// Called from COPersistentRoot

- (void) recordPersistentRootCreation: (COPersistentRoot *)aPersistentRoot
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandDeletePersistentRoot *edit = [[[COCommandDeletePersistentRoot alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    
    [self recordEditInverse: edit];
}
- (void) recordPersistentRoot: (COPersistentRoot *)aPersistentRoot
             setCurrentBranch: (COBranch *)aBranch
                    oldBranch: (COBranch *)oldBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandSetCurrentBranch *edit = [[[COCommandSetCurrentBranch alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    
    edit.oldBranchUUID = [aBranch UUID];
    edit.branchUUID = [oldBranch UUID];
    
    [self recordEditInverse: edit];
}

// Called from COBranch

- (void) recordBranchCreation: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandDeleteBranch *edit = [[[COCommandDeleteBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordEditInverse: edit];
}

- (void) recordBranchSetCurrentRevision: (COBranch *)aBranch
                          oldRevisionID: (CORevisionID *)aRevisionID
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COCommandSetCurrentVersionForBranch *edit = [[[COCommandSetCurrentVersionForBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    edit.oldRevisionID = [[aBranch currentRevision] revisionID];
    edit.revisionID = aRevisionID;
    
    [self recordEditInverse: edit];
}

- (void) recordBranchSetMetadata: (COBranch *)aBranch
                     oldMetadata: (id)oldMetadata
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COCommandSetBranchMetadata *edit = [[[COCommandSetBranchMetadata alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    edit.oldMetadata = [aBranch metadata];
    edit.metadata = oldMetadata;
    
    [self recordEditInverse: edit];
}

- (void) recordBranchDeletion: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandUndeleteBranch *edit = [[[COCommandUndeleteBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordEditInverse: edit];
}

- (void) recordBranchUndeletion: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
  
    COCommandDeleteBranch *edit = [[[COCommandDeleteBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordEditInverse: edit];
}

@end
