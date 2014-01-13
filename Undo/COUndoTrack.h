/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
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
 *
 * You shouldn't subclass COUndoTrack.
 */
@interface COUndoTrack : NSObject <COTrack>
{
	@private
    COUndoStackStore *_store;
    NSString *_name;
	NSMutableArray *_commands;
	COEditingContext *_editingContext;
	
	BOOL _coalescing;
	ETUUID *_lastCoalescedCommandUUID;
}


/** @taskunit Track Access and Creation */


/**
 * Returns the persistent track bound to the given name, or creates it in case 
 * it doesn't exist yet. 
 *
 * See -editingContext.
 */
+ (COUndoTrack *)trackForName: (NSString *)aName
           withEditingContext: (COEditingContext *)aContext;
/**
 * Returns a non-recordable track that provides a union view over all persistent 
 * tracks that match the given pattern.
 *
 * The returned track must not be passed to commit methods e.g.  
 * -[COEditingContext commmitWithIdentitifer:undoTrack:], otherwise the commit 
 * raises an exception.
 *
 * See -editingContext.
 */
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


/**
 * Discards all the commands.
 */
- (void)clear;

- (void)beginCoalescing;
- (void)endCoalescing;

/** @taskunit Framework Private */


/**
 * Saves the command on disk and remembers it as the current command.
 *
 * See also -currentCommand.
 */
- (void) recordCommand: (COCommand *)aCommand;

@end
