#import <CoreObject/COEditingContext.h>

@interface COEditingContext (Undo)

- (BOOL) canUndoForStackNamed: (NSString *)aName;
- (BOOL) canRedoForStackNamed: (NSString *)aName;

- (BOOL) undoForStackNamed: (NSString *)aName;
- (BOOL) redoForStackNamed: (NSString *)aName;

/**
 * Replacement for -commit that also writes a COEdit to the requested undo stack
 *
 * TODO: Will require undo group object.
 */
- (BOOL) commitWithStackNamed: (NSString *)aName;

@end
