#import "COEditingContext+Undo.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"
#import "COUndoStackStore.h"
#import "COEdit.h"
#import "COEditGroup.h"
#import <EtoileFoundation/Macros.h>

#import "COEditGroup.h"
#import "COEditDeleteBranch.h"
#import "COEditUndeleteBranch.h"
#import "COEditSetBranchMetadata.h"
#import "COEditSetCurrentBranch.h"
#import "COEditSetCurrentVersionForBranch.h"
#import "COEditDeletePersistentRoot.h"
#import "COEditUndeletePersistentRoot.h"

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
    return [self canApplyEdit: edit];
}

- (BOOL) canRedoForStackNamed: (NSString *)aName
{
    COEdit *edit = [self peekEditFromStack: kCORedoStack forName: aName];
    return [self canApplyEdit: edit];
}

- (BOOL) popAndApplyFromStack: (NSString *)popStack pushToStack: (NSString*)pushStack name: (NSString *)aName
{
    [_undoStackStore beginTransaction];
    
    COEdit *edit = [self peekEditFromStack: popStack forName: aName];
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
    COEdit *inverse = [edit inverse];

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
    
    if (_isRecordingUndo)
    {
        if ([_currentEditGroup.contents isEmpty])
        {
            NSLog(@"-recordEndUndoGroup contents is empty!");
            DESTROY(_currentEditGroup);
            return;
        }

        // Optimisation: collapse COEditGroups that contain only one child
        COEdit *objectToSerialize =
            (1 == [_currentEditGroup.contents count])
            ? [_currentEditGroup.contents firstObject]
            : _currentEditGroup;
        
        id plist = [objectToSerialize plist];        
        NSLog(@"Undo event: %@", plist);
        
        // N.B. The kCOUndoStack contains COEdits that are the inverse of
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

- (void) recordEditInverse: (COEdit*)anInverse
{
    [_currentEditGroup.contents addObject: anInverse];
}

// Called from COEditingContext

- (void) recordPersistentRootDeletion: (COPersistentRoot *)aPersistentRoot
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COEditUndeletePersistentRoot *edit = [[[COEditUndeletePersistentRoot alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Delete Persistent Root";
    
    [self recordEditInverse: edit];
}
- (void) recordPersistentRootUndeletion: (COPersistentRoot *)aPersistentRoot
{
    NSLog(@"%@", NSStringFromSelector(_cmd));

    COEditDeletePersistentRoot *edit = [[[COEditDeletePersistentRoot alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Undelete Persistent Root";
    
    [self recordEditInverse: edit];
}

// Called from COPersistentRoot

- (void) recordPersistentRootCreation: (COPersistentRoot *)aPersistentRoot
{
    NSLog(@"%@", NSStringFromSelector(_cmd));

    COEditDeletePersistentRoot *edit = [[[COEditDeletePersistentRoot alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Create Persistent Root";
    
    [self recordEditInverse: edit];
}
- (void) recordPersistentRoot: (COPersistentRoot *)aPersistentRoot
             setCurrentBranch: (COBranch *)aBranch
                    oldBranch: (COBranch *)oldBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));

    COEditSetCurrentBranch *edit = [[[COEditSetCurrentBranch alloc] init] autorelease];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Switch Branch";
    
    edit.oldBranchUUID = [aBranch UUID];
    edit.branchUUID = [oldBranch UUID];
    
    [self recordEditInverse: edit];
}

// Called from COBranch

- (void) recordBranchCreation: (COBranch *)aBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));

    COEditDeleteBranch *edit = [[[COEditDeleteBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Create branch";
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordEditInverse: edit];
}

- (void) recordBranchSetCurrentRevision: (COBranch *)aBranch
                          oldRevisionID: (CORevisionID *)aRevisionID
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COEditSetCurrentVersionForBranch *edit = [[[COEditSetCurrentVersionForBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Revert or Commit";
    
    edit.branchUUID = [aBranch UUID];
    edit.oldRevisionID = [[aBranch currentRevision] revisionID];
    edit.revisionID = aRevisionID;
    
    [self recordEditInverse: edit];
}

- (void) recordBranchSetMetadata: (COBranch *)aBranch
                     oldMetadata: (id)oldMetadata
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COEditSetBranchMetadata *edit = [[[COEditSetBranchMetadata alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Set Branch Metadata";
    
    edit.branchUUID = [aBranch UUID];
    edit.oldMetadata = [aBranch metadata];
    edit.metadata = oldMetadata;
    
    [self recordEditInverse: edit];
}

- (void) recordBranchDeletion: (COBranch *)aBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));

    COEditUndeleteBranch *edit = [[[COEditUndeleteBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Delete branch";
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordEditInverse: edit];
}

- (void) recordBranchUndeletion: (COBranch *)aBranch
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
  
    COEditDeleteBranch *edit = [[[COEditDeleteBranch alloc] init] autorelease];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] persistentRootUUID];
    edit.timestamp = [NSDate date];
    edit.displayName = @"Undelete branch";
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordEditInverse: edit];
}

@end
