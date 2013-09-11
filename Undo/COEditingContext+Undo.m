#import "COEditingContext+Undo.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"
#import "COUndoStackStore.h"
#import "COUndoStack.h"
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

- (void) recordEndUndoGroupWithUndoStack: (COUndoStack *)aStack
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
        
        [aStack recordCommandInverse: objectToSerialize];
        
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
