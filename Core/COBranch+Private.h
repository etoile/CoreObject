#import <CoreObject/COBranch.h>

@interface COBranch ()

/** @taskunit Private */

- (id)        initWithUUID: (ETUUID *)aUUID
        objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
            persistentRoot: (COPersistentRoot *)aPersistentRoot
parentRevisionForNewBranch: (CORevisionID *)parentRevisionForNewBranch;

- (void)didMakeInitialCommitWithRevisionID: (CORevisionID *)aRevisionID;
- (void) saveCommitWithMetadata: (NSDictionary *)metadata;
- (void)saveDeletion;
- (BOOL) isBranchUncommitted;

@end