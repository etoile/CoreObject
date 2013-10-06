#import <Foundation/Foundation.h>
#import <CoreObject/COTrack.h>

@class COUndoStackStore, COEditingContext, COCommand;

extern NSString * const COUndoStackDidChangeNotification;

extern NSString * const kCOUndoStackName;

// FIXME: Confusing name, because a COUndoStack actually represents
// a pair of stacks (undo and redo). Rename to "COUndoLog" ?
// COUndoHistory ?
@interface COUndoStack : NSObject <COTrack>
{
	@private
    COUndoStackStore *_store;
    NSString *_name;
	NSMutableArray *_commands;
	COEditingContext *_editingContext;
}

@property (strong, readonly, nonatomic) COUndoStackStore *store;
@property (strong, readonly, nonatomic) NSString *name;

@property (weak, readonly, nonatomic) NSArray *undoNodes;
@property (weak, readonly, nonatomic) NSArray *redoNodes;

// TODO: We need to decide whether we allow to use the same stack with multiple
// editing contexts at the same time, or if we change -setCurrentNode: to
// -setCurrentNode:withEditingContext:. Using multiple editing contexts with
// the same stack seems dangerous to me.
@property (nonatomic, strong) COEditingContext *editingContext;

- (void) clear;

- (BOOL) canUndoWithEditingContext: (COEditingContext *)aContext;
- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext;

- (void) undoWithEditingContext: (COEditingContext *)aContext;
- (void) redoWithEditingContext: (COEditingContext *)aContext;

/** @taskunit Framework Private */

- (void) recordCommand: (COCommand *)aCommand;

@end
