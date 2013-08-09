#import <Cocoa/Cocoa.h>

#import <CoreObject/CoreObject.h>

#import "EWUndoManager.h"

@interface EWDocument : NSDocument <EWUndoManagerDelegate>
{
    COPersistentRoot  *_persistentRoot;
}


- (IBAction) branch: (id)sender;
- (IBAction) showBranches: (id)sender;
- (IBAction) history: (id)sender;
- (IBAction) pickboard: (id)sender;

- (void) recordNewState: (COItemGraph*)aState;

- (COPersistentRootInfo *) currentPersistentRoot;
- (COSQLiteStore *) store;

- (ETUUID *) editingBranch;

/**
 * @param aToken
 *   should be a state token that belongs to [self editingBranch]
 */
- (void) loadStateToken: (CORevisionID *)aToken;

/**
 * @param aToken
 *   should be a state token that belongs to [self editingBranch]
 */
- (void) persistentSwitchToStateToken: (CORevisionID *)aToken;

- (void) switchToBranch: (ETUUID *)aBranchUUID;

- (void) deleteBranch: (ETUUID *)aBranchUUID;

@end
