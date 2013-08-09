#import <Cocoa/Cocoa.h>

@protocol EWUndoManagerDelegate

- (void) undo;
- (void) redo;

- (BOOL) canUndo;
- (BOOL) canRedo;

- (NSString *) undoMenuItemTitle;
- (NSString *) redoMenuItemTitle;

@end

@interface EWUndoManager : NSObject
{
    id<EWUndoManagerDelegate> delegate_;
}

- (void) setDelegate: (id<EWUndoManagerDelegate>)delegate;

- (void) undo;
- (void) redo;

- (BOOL) canUndo;
- (BOOL) canRedo;

- (NSString *) undoMenuItemTitle;
- (NSString *) redoMenuItemTitle;

@end
