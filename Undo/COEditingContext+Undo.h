#import <CoreObject/COEditingContext.h>

@class COUndoStack;

/**
 * Goals for the app level undo system:
 *
 *  - Support use cases listed in TODO with one API/implementation
 *  - Stay as decoupled as possible from the rest of CoreObject
 *  - Easy for applications to extend with their own undo actions for manipulating
 *    state not managed by CoreObject. (Ideally all state would be tracked by
 *    CoreObject, but I felt this goal would improve the design anyway.)
 *
 * The concept behind the app-level undo system is, there is a per-user database
 * (separate from any CoreObject stores) that stores the user's undo/redo stacks.
 * (stored in ~/Library/CoreObject/Undo/undo.sqlite)
 *
 * When saving a batch of changes with a COEditingContext, you can optionally
 * record the edits in an undo stack. You can pass any string you want to
 * -commitWithStackNamed: and the inverse edit (or edit group) will be pushed onto that
 * persistent stack, creating it if needed.
 *
 * The undo stack database (COUndoStackStore) stores pairs of undo/redo stacks
 * indexed by name. The name is just a flat string; we may want to have suggested 
 * naming schemes. Examples could be:
 *
 * "<application id>" -- for apps using one stack for several persistent roots
 * "<application id>:<persistent root UUID>" -- for apps using one stack per persistent root
 * "<application id>:<persistent root UUID>@username" -- for collaborative editing
 * "<application id>:<persistent root UUID>:<tab/pane name>" -- for a multipane editor
 *
 * Importantly, the names are just treated as opaque identifiers to CoreObject,
 * and the behaviour comes from which edits apps put in which stacks.
 *
 * This design should support all of these use-cases:
 *
 *  - per-window/tab/pane undo stacks when editing a single persistent root
 *    (e.g. for a graphics editor with split views editing two different parts
 *     of a a document, each pane can have its own stack)
 *
 *  - per-app undo stack for a manager application editing many persistent roots
 *
 *  - per-user undo stacks when editing a shared document.
 */
@interface COEditingContext (Undo)

/** @taskunit App-level undo/redo */

- (void) commitWithUndoStack: (COUndoStack *)aStack;

/** @taskunit Deprecated */

- (BOOL) canUndoForStackNamed: (NSString *)aName;
- (BOOL) canRedoForStackNamed: (NSString *)aName;

- (BOOL) undoForStackNamed: (NSString *)aName;
- (BOOL) redoForStackNamed: (NSString *)aName;

/**
 * Replacement for -commit that also writes a COCommand to the requested undo stack
 */
- (BOOL) commitWithStackNamed: (NSString *)aName;

/** @taskunit Framework Private */

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
