#import "COEditingContext+Undo.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"
#import "COUndoStackStore.h"
#import "COUndoTrack.h"
#import "COCommand.h"
#import "COCommandGroup.h"
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

@implementation COEditingContext (Undo)

// Methods called during commit

// Called from COEditingContext

- (void) recordBeginUndoGroup
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (_isRecordingUndo)
    {
        _currentEditGroup = [[COCommandGroup alloc] init];
    }
    else
    {
        _currentEditGroup = nil;
    }
}

- (COCommand *) recordEndUndoGroupWithUndoTrack: (COUndoTrack *)track
{
    if (_isRecordingUndo == NO)
		return nil;

	if ([_currentEditGroup.contents isEmpty])
	{
		// TODO: Raise an exception
		NSLog(@"-recordEndUndoGroup contents is empty!");
		_currentEditGroup = nil;
		return nil;
	}

	COCommand *recordedCommand = _currentEditGroup;

	// Optimisation: collapse COCommandGroups that contain only one child
	if ([_currentEditGroup.contents count] == 1)
	{
		recordedCommand = [_currentEditGroup.contents firstObject];
	}

	[track recordCommand: recordedCommand];
	
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
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
    [self recordCommand: edit];
}
- (void) recordPersistentRootUndeletion: (COPersistentRoot *)aPersistentRoot
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandUndeletePersistentRoot *edit = [[COCommandUndeletePersistentRoot alloc] init];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
    [self recordCommand: edit];
}

// Called from COPersistentRoot

- (void) recordPersistentRootCreation: (COPersistentRoot *)aPersistentRoot
                  atInitialRevisionID: (CORevisionID *)aRevID
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandCreatePersistentRoot *edit = [[COCommandCreatePersistentRoot alloc] init];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
	edit.initialRevisionID = aRevID;
    
    [self recordCommand: edit];
}
- (void) recordPersistentRoot: (COPersistentRoot *)aPersistentRoot
             setCurrentBranch: (COBranch *)aBranch
                    oldBranch: (COBranch *)oldBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandSetCurrentBranch *edit = [[COCommandSetCurrentBranch alloc] init];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
    
    edit.oldBranchUUID = [oldBranch UUID];
    edit.branchUUID = [aBranch UUID];
    
    [self recordCommand: edit];
}

// Called from COBranch

- (void) recordBranchCreation: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

	// TODO: Implement COCommandCreateBranch
    COCommandUndeleteBranch *edit = [[COCommandUndeleteBranch alloc] init];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordCommand: edit];
}

- (void) recordBranchSetCurrentRevisionID: (CORevisionID *)current
                            oldRevisionID: (CORevisionID *)old
						   headRevisionID: (CORevisionID *)head
                        oldHeadRevisionID: (CORevisionID *)oldHead
                                 ofBranch: (COBranch *)aBranch

{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COCommandSetCurrentVersionForBranch *edit = [[COCommandSetCurrentVersionForBranch alloc] init];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    edit.oldRevisionID = old;
    edit.revisionID = current;
	edit.headRevisionID = head;
	edit.oldHeadRevisionID = oldHead;
    
    [self recordCommand: edit];
}

- (void) recordBranchSetMetadata: (COBranch *)aBranch
                     oldMetadata: (id)oldMetadata
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    COCommandSetBranchMetadata *edit = [[COCommandSetBranchMetadata alloc] init];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    edit.oldMetadata = oldMetadata;
    edit.metadata = [aBranch metadata];
    
    [self recordCommand: edit];
}

- (void) recordBranchDeletion: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandDeleteBranch *edit = [[COCommandDeleteBranch alloc] init];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordCommand: edit];
}

- (void) recordBranchUndeletion: (COBranch *)aBranch
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
  
    COCommandUndeleteBranch *edit = [[COCommandUndeleteBranch alloc] init];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordCommand: edit];
}

@end
