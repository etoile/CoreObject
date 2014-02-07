/*
	Copyright (C) 2012 Eric Wasylishen
 
	Date:  October 2012
	License:  MIT  (see COPYING)
 */


#import <Cocoa/Cocoa.h>

@protocol EWUndoManagerDelegate

- (void) undo;
- (void) redo;

- (BOOL) canUndo;
- (BOOL) canRedo;

- (NSString *) undoMenuItemTitle;
- (NSString *) redoMenuItemTitle;

@end

/**
 * Bridge class for letting a 3rd-part undo manager provide undo where 
 * an NSUndoManager is expected.
 *
 * The 3rd-party undo manager can be anything implementing EWUndoManagerDelegate.
 *
 * EWUndoManager can be passed to AppKit in a context where AppKit is expecting
 * an NSUndoManager subclass (e.g., NSWindowDelegate -windowWillReturnUndoManager).
 */
@interface EWUndoManager : NSObject
{
    id<EWUndoManagerDelegate> __weak delegate_;
}

- (void) setDelegate: (id<EWUndoManagerDelegate>)delegate;

- (void) undo;
- (void) redo;

- (BOOL) canUndo;
- (BOOL) canRedo;

- (NSString *) undoMenuItemTitle;
- (NSString *) redoMenuItemTitle;

@end
