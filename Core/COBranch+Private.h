#import <CoreObject/COBranch.h>

@interface COBranch ()

/** @taskunit Private */

- (id)        initWithUUID: (ETUUID *)aUUID
        objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
            persistentRoot: (COPersistentRoot *)aPersistentRoot
          parentBranchUUID: (ETUUID *)aParentBranchUUID
parentRevisionForNewBranch: (CORevisionID *)parentRevisionForNewBranch;

- (void)updateWithBranchInfo: (COBranchInfo *)branchInfo;
- (COBranchInfo *)branchInfo;

- (void)didMakeInitialCommitWithRevisionID: (CORevisionID *)aRevisionID;
- (void) saveCommitWithMetadata: (NSDictionary *)metadata;
- (void)saveDeletion;
- (BOOL) isBranchUncommitted;

@end