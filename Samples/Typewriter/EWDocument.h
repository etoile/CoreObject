#import <Cocoa/Cocoa.h>

#import <CoreObject/CoreObject.h>

#import "EWUndoManager.h"

@interface EWDocument : NSDocument <EWUndoManagerDelegate>
{
    NSString *_title;
    COPersistentRoot  *_persistentRoot;
}

- (id) initWithPersistentRoot: (COPersistentRoot *)aRoot title: (NSString *)aTitle;

- (IBAction) branch: (id)sender;
- (IBAction) showBranches: (id)sender;
- (IBAction) history: (id)sender;
- (IBAction) pickboard: (id)sender;

- (IBAction) push: (id)sender;
- (IBAction) pull: (id)sender;

- (void) recordUpdatedItems: (NSArray *)items;

- (COPersistentRoot *) currentPersistentRoot;
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

- (void) commit;

@end
