#import <CoreObject/COEditingContext.h>

@interface COEditingContext (Undo)

- (BOOL) canUndoForStackNamed: (NSString *)aName;
- (BOOL) canRedoForStackNamed: (NSString *)aName;

- (BOOL) undoForStackNamed: (NSString *)aName;
- (BOOL) redoForStackNamed: (NSString *)aName;

/**
 * Replacement for -commit that also writes a COEdit to the requested undo stack
 */
- (BOOL) commitWithStackNamed: (NSString *)aName;

// Called from COEditingContext

- (void) recordBeginUndoGroup;
- (void) recordEndUndoGroup;

- (void) recordPersistentRootDeletion: (COPersistentRoot *)aPersistentRoot;
- (void) recordPersistentRootUndeletion: (COPersistentRoot *)aPersistentRoot;

// Called from COPersistentRoot

- (void) recordPersistentRootCreation: (COPersistentRoot *)info;
- (void) recordPersistentRoot: (COPersistentRoot *)aPersistentRoot
             setCurrentBranch: (COBranch *)aBranch
                    oldBranch: (COBranch *)oldBranch;

// Called from COBranch

- (void) recordBranchCreation: (COBranch *)aBranch;
- (void) recordBranchSetCurrentRevision: (COBranch *)aBranch
                          oldRevisionID: (CORevisionID *)aRevisionID;
- (void) recordBranchSetMetadata: (COBranch *)aBranch
                     oldMetadata: (id)oldMetadata;
- (void) recordBranchDeletion: (COBranch *)aBranch;
- (void) recordBranchUndeletion: (COBranch *)aBranch;

@end
