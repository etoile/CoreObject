/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  September 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COTrack.h>

@class COUndoStackStore, COEditingContext, COCommand;

extern NSString * const COUndoStackDidChangeNotification;
extern NSString * const kCOUndoStackName;

/**
 * @group History Interaction
 *
 * An undo track represents a history track that can record commits selectively. 
 *
 * For a commit done in an editing context, an undo track can be passed using 
 * –[COEditingContext commitWithIdentifier:undoStack:]. When the commit is saved, 
 * the editing context records the commit as a command using -recordCommand:.
 * At this point, the undo track saves the command on disk.
 *
 * Commits that contain object graph context changes result in new revisions in 
 * the store. For other commits that just contain store structure changes:
 *
 * <list>
 * <item>branch creation</item>
 * <item>branch deletion</item>
 * <item>branch undeletion</item>
 * <item>branch switch</item>
 * <item>branch revision change</item>
 * <item>branch metadata editing (e.g. branch renaming)</item>
 * <item>persistent root creation</item>
 * <item>persistent root deletion</item>
 * <item>persistent root undeletion</item>
 * </list>
 *
 * no new revisions is created. The store doesn't record them in any way.
 *
 * However an undo track can track both: 
 * 
 * <list>
 * <item>store structure history (represented as custom commands e.g. COCommandDeleteBranch etc.)
 * <item>branch history (represented as COCommandNewRevisionForBranch)
 * </list>
 *
 * undo tracks can track all these changes or a subset per application or per 
 * use cases, and provide undo/redo support. For undo/redo menu actions, never 
 * manipulate the branch history directly, but use an undo track.
 *
 * You can navigate the command sequence to change the editing context state 
 * using -undo, -redo and -setCurrentNode:. COUndoStack supports the same 
 * history navigation protocol than COBranch.
 */
@interface COUndoTrack : NSObject <COTrack>
{
	@private
    COUndoStackStore *_store;
    NSString *_name;
	NSMutableArray *_commands;
	COEditingContext *_editingContext;
}


/** @taskunit Track Access and Creation */


+ (COUndoTrack *)trackForName: (NSString *)aName
           withEditingContext: (COEditingContext *)aContext;
+ (COUndoTrack *)trackForPattern: (NSString *)aPattern
              withEditingContext: (COEditingContext *)aContext;

/** @taskunit Basic Properties */


/**
 * The unique name bound to the stack.
 */
@property (nonatomic, readonly) NSString *name;
/**
 * The editing context that is changed if -undo, -redo or -setCurrentNode: are 
 * called.
 *
 * If you pass an undo track to -[COEditingContext commitWithIdentifier:undoStack:], 
 * then usually you want undo and redo to apply to the same editing context. 
 * To do so, just set up the undo track using -[COUndoStack setEditingContext:].
 */
@property (nonatomic, readonly) COEditingContext *editingContext;


/** @taskunit Undo and Redo */

/**
 * Returns whether the current command can be undone in the editing context.
 */
- (BOOL)canUndo;
/**
 * Returns whether the last undone command can be redone in the editing context.
 */
- (BOOL)canRedo;
/**
 * Undoes the current command in the editing context.
 */
- (void)undo;
/**
 * Reapplies the last undone command in the editing context.
 */
- (void)redo;

/**
 * Discards all the commands.
 */
- (void)clear;


/** @taskunit Framework Private */


/**
 * Saves the command on disk and remembers it as the current command.
 *
 * See also -currentCommand.
 */
- (void) recordCommand: (COCommand *)aCommand;


/** @taskunit Deprecated */


- (BOOL) canUndoWithEditingContext: (COEditingContext *)aContext;
- (BOOL) canRedoWithEditingContext: (COEditingContext *)aContext;
- (void) undoWithEditingContext: (COEditingContext *)aContext;
- (void) redoWithEditingContext: (COEditingContext *)aContext;

@property (weak, readonly, nonatomic) NSArray *undoNodes;
@property (weak, readonly, nonatomic) NSArray *redoNodes;

@end
