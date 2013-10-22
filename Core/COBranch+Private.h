/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import <CoreObject/COBranch.h>

@interface COBranch ()

/** @taskunit Private */

- (id)        initWithUUID: (ETUUID *)aUUID
        objectGraphContext: (COObjectGraphContext *)anObjectGraphContext
            persistentRoot: (COPersistentRoot *)aPersistentRoot
          parentBranchUUID: (ETUUID *)aParentBranchUUID
parentRevisionForNewBranch: (ETUUID *)parentRevisionForNewBranch;

- (void)updateWithBranchInfo: (COBranchInfo *)branchInfo;
- (COBranchInfo *)branchInfo;

- (void)didMakeInitialCommitWithRevisionID: (ETUUID *)aRevisionID transaction: (COStoreTransaction *)txn;
- (void) saveCommitWithMetadata: (NSDictionary *)metadata transaction: (COStoreTransaction *)txn;
- (void)saveDeletionWithTransaction: (COStoreTransaction *)txn;
- (BOOL) isBranchUncommitted;

- (void)updateRevisions;

@property (readwrite, nonatomic) CORevision *headRevision;

@end