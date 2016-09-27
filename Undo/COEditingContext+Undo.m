/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COEditingContext+Undo.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"
#import "COUndoTrack.h"
#import "COCommand.h"
#import "COCommandGroup.h"
#import "COCommitDescriptor.h"
#import <EtoileFoundation/Macros.h>
#import "COSQLiteStore.h"

#import "COCommandGroup.h"
#import "COCommandDeleteBranch.h"
#import "COCommandUndeleteBranch.h"
#import "COCommandSetBranchMetadata.h"
#import "COCommandSetCurrentBranch.h"
#import "COCommandSetCurrentVersionForBranch.h"
#import "COCommandDeletePersistentRoot.h"
#import "COCommandUndeletePersistentRoot.h"
#import "COCommandSetPersistentRootMetadata.h"

@implementation COEditingContext (Undo)

// Methods called during commit

// Called from COEditingContext

- (void) recordBeginUndoGroupWithMetadata: (NSDictionary *)metadata
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (_recordingUndo)
    {
        _currentEditGroup = [[COCommandGroup alloc] init];
        _currentEditGroup.metadata = metadata;
    }
    else
    {
        _currentEditGroup = nil;
    }
}

- (COCommandGroup *) recordEndUndoGroupWithUndoTrack: (COUndoTrack *)track
{
    if (!_recordingUndo)
        return nil;

    if ([_currentEditGroup.contents isEmpty])
    {
        // TODO: Raise an exception
        NSLog(@"-recordEndUndoGroup contents is empty!");
        _currentEditGroup = nil;
        return nil;
    }

    [track recordCommand: _currentEditGroup];

    COCommandGroup *recordedCommand = _currentEditGroup;
    _currentEditGroup = nil;

    return recordedCommand;
}

- (void) recordCommand: (COCommand *)aCommand
{
    [_currentEditGroup.contents addObject: aCommand];
}

// Called from COEditingContext

- (void) recordPersistentRootDeletion: (COPersistentRoot *)aPersistentRoot
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COCommandDeletePersistentRoot *edit = [[COCommandDeletePersistentRoot alloc] init];
    edit.storeUUID = aPersistentRoot.editingContext.store.UUID;
    edit.persistentRootUUID = aPersistentRoot.UUID;
    [self recordCommand: edit];
}
- (void) recordPersistentRootUndeletion: (COPersistentRoot *)aPersistentRoot
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandUndeletePersistentRoot *edit = [[COCommandUndeletePersistentRoot alloc] init];
    edit.storeUUID = aPersistentRoot.editingContext.store.UUID;
    edit.persistentRootUUID = aPersistentRoot.UUID;
    [self recordCommand: edit];
}

// Called from COPersistentRoot

- (void) recordPersistentRootCreation: (COPersistentRoot *)aPersistentRoot
                  atInitialRevisionID: (ETUUID *)aRevID
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandCreatePersistentRoot *edit = [[COCommandCreatePersistentRoot alloc] init];
    edit.storeUUID = aPersistentRoot.editingContext.store.UUID;
    edit.persistentRootUUID = aPersistentRoot.UUID;
    edit.initialRevisionID = aRevID;
    
    [self recordCommand: edit];
}
- (void) recordPersistentRoot: (COPersistentRoot *)aPersistentRoot
             setCurrentBranch: (COBranch *)aBranch
                    oldBranch: (COBranch *)oldBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandSetCurrentBranch *edit = [[COCommandSetCurrentBranch alloc] init];
    edit.storeUUID = aPersistentRoot.editingContext.store.UUID;
    edit.persistentRootUUID = aPersistentRoot.UUID;
    
    edit.oldBranchUUID = oldBranch.UUID;
    edit.branchUUID = aBranch.UUID;
    
    [self recordCommand: edit];
}

- (void) recordPersistentRootSetMetadata: (COPersistentRoot *)aPersistentRoot
                             oldMetadata: (id)oldMetadata
{
    COCommandSetPersistentRootMetadata *edit = [[COCommandSetPersistentRootMetadata alloc] init];
    edit.storeUUID = aPersistentRoot.editingContext.store.UUID;
    edit.persistentRootUUID = aPersistentRoot.UUID;
    
    edit.oldMetadata = oldMetadata;
    edit.metadata = aPersistentRoot.metadata;
    
    [self recordCommand: edit];
}

// Called from COBranch

- (void) recordBranchCreation: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    // TODO: Implement COCommandCreateBranch
    COCommandUndeleteBranch *edit = [[COCommandUndeleteBranch alloc] init];
    edit.storeUUID = aBranch.editingContext.store.UUID;
    edit.persistentRootUUID = aBranch.persistentRoot.UUID;
    
    edit.branchUUID = aBranch.UUID;
    
    [self recordCommand: edit];
}

- (void) recordBranchSetCurrentRevisionUUID: (ETUUID *)current
                            oldRevisionUUID: (ETUUID *)old
                           headRevisionUUID: (ETUUID *)head
                        oldHeadRevisionUUID: (ETUUID *)oldHead
                                   ofBranch: (COBranch *)aBranch

{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    NILARG_EXCEPTION_TEST(current);
    NILARG_EXCEPTION_TEST(old);
    NILARG_EXCEPTION_TEST(head);
    NILARG_EXCEPTION_TEST(oldHead);
    NILARG_EXCEPTION_TEST(aBranch);
    
    COCommandSetCurrentVersionForBranch *edit = [[COCommandSetCurrentVersionForBranch alloc] init];
    edit.storeUUID = aBranch.editingContext.store.UUID;
    edit.persistentRootUUID = aBranch.persistentRoot.UUID;
    
    edit.branchUUID = aBranch.UUID;
    edit.oldRevisionUUID = old;
    edit.revisionUUID = current;
    edit.headRevisionUUID = head;
    edit.oldHeadRevisionUUID = oldHead;
    
    [self recordCommand: edit];
}

- (void) recordBranchSetMetadata: (COBranch *)aBranch
                     oldMetadata: (id)oldMetadata
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COCommandSetBranchMetadata *edit = [[COCommandSetBranchMetadata alloc] init];
    edit.storeUUID = aBranch.editingContext.store.UUID;
    edit.persistentRootUUID = aBranch.persistentRoot.UUID;
    
    edit.branchUUID = aBranch.UUID;
    edit.oldMetadata = oldMetadata;
    edit.metadata = aBranch.metadata;
    
    [self recordCommand: edit];
}

- (void) recordBranchDeletion: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandDeleteBranch *edit = [[COCommandDeleteBranch alloc] init];
    edit.storeUUID = aBranch.editingContext.store.UUID;
    edit.persistentRootUUID = aBranch.persistentRoot.UUID;
    
    edit.branchUUID = aBranch.UUID;
    
    [self recordCommand: edit];
}

- (void) recordBranchUndeletion: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
  
    COCommandUndeleteBranch *edit = [[COCommandUndeleteBranch alloc] init];
    edit.storeUUID = aBranch.editingContext.store.UUID;
    edit.persistentRootUUID = aBranch.persistentRoot.UUID;
    
    edit.branchUUID = aBranch.UUID;
    
    [self recordCommand: edit];
}

@end
