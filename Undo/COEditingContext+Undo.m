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
#import "COCommandSetPersistentRootMetadata.h"

@implementation COEditingContext (Undo)

// Methods called during commit

// Called from COEditingContext

- (void) recordBeginUndoGroup
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (_isRecordingUndo)
    {
        _currentEditGroup = [[COCommandGroup alloc] init];
		_currentEditGroup.UUID = [ETUUID new];
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
	edit.UUID = [ETUUID new];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
    [self recordCommand: edit];
}
- (void) recordPersistentRootUndeletion: (COPersistentRoot *)aPersistentRoot
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandUndeletePersistentRoot *edit = [[COCommandUndeletePersistentRoot alloc] init];
	edit.UUID = [ETUUID new];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
    [self recordCommand: edit];
}

// Called from COPersistentRoot

- (void) recordPersistentRootCreation: (COPersistentRoot *)aPersistentRoot
                  atInitialRevisionID: (ETUUID *)aRevID
{
//    NSLog(@"%@", NSStringFromSelector(_cmd));

    COCommandCreatePersistentRoot *edit = [[COCommandCreatePersistentRoot alloc] init];
	edit.UUID = [ETUUID new];
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
	edit.UUID = [ETUUID new];
    edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
    
    edit.oldBranchUUID = [oldBranch UUID];
    edit.branchUUID = [aBranch UUID];
    
    [self recordCommand: edit];
}

- (void) recordPersistentRootSetMetadata: (COPersistentRoot *)aPersistentRoot
							 oldMetadata: (id)oldMetadata
{
	COCommandSetPersistentRootMetadata *edit = [[COCommandSetPersistentRootMetadata alloc] init];
	edit.UUID = [ETUUID new];
	edit.storeUUID = [[[aPersistentRoot editingContext] store] UUID];
    edit.persistentRootUUID = [aPersistentRoot UUID];
    edit.timestamp = [NSDate date];
    
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
	edit.UUID = [ETUUID new];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
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
	edit.UUID = [ETUUID new];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
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
	edit.UUID = [ETUUID new];
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
	edit.UUID = [ETUUID new];
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
	edit.UUID = [ETUUID new];
    edit.storeUUID = [[[aBranch editingContext] store] UUID];
    edit.persistentRootUUID = [[aBranch persistentRoot] UUID];
    edit.timestamp = [NSDate date];
    
    edit.branchUUID = [aBranch UUID];
    
    [self recordCommand: edit];
}

@end
