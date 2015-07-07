/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COTrack.h>

@class COUndoTrackStore, COUndoTrackState, COEditingContext, COCommand, COCommandGroup;

/**
 * Posted when the undo track content or current command changes, this includes 
 * changes done in another process or in related local track objects (e.g. a
 * track instance with the same name or a pattern track matching the observed 
 * track).
 *
 * This notification is posted every time the track is reloaded.
 *
 * It will tell you about COUndoTrack changes exposed through the COTrack protocol:
 *
 * <deflist>
 * <term>basic undo/redo or a move to a past or future state along the track</term>
 * <desc>-[COTrack currentNode] has changed</desc>
 * <term>new commit, including selective undo</term>
 * <desc>a new node has been recorded in -[COTrack nodes]</desc>
 * </deflist>
 *
 * The user info dictionary contains the key: kCOundoTrackName.
 *
 * Note: tracks are append-only, so node removal is not supported.
 */
extern NSString * const COUndoTrackDidChangeNotification;
/**
 * Key in the userInfo dictionary for COUndoTrackDidChangeNotification. 
 *
 * The value is an NSString containing the track name of the track that changed.
 */
extern NSString * const kCOUndoTrackName;

/**
 * @group Undo
 * @abstract An undo track represents a history track that can record commits 
 * selectively. 
 *
 * For a commit done in an editing context, an undo track can be passed using 
 * -[COEditingContext commitWithIdentifier:metadata:undoTrack:error:] or 
 * similar commit methods. When the commit is saved, the editing context 
 * records the commit as a command using -recordCommand:. At this point, the 
 * undo track saves the command on disk.
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
 * <item>store structure history (represented as custom commands e.g. 
 * COCommandDeleteBranch etc.)</item>
 * <item>branch history (new revisions represented as 
 * COCommandSetVersionForBranch)</item>
 * </list>
 *
 * Undo tracks can track all these changes or a subset per application or per 
 * use cases, and provide undo/redo support. For undo/redo menu actions, never 
 * manipulate the branch history directly, but use an undo track.
 *
 * You can navigate the command sequence to change the editing context state 
 * using -undo, -redo and -setCurrentNode:. COUndoTrack supports the same 
 * history navigation protocol than COBranch. Note that the COUndoTrack 
 * implementation (of these COTrack methods) can perform an editing context 
 * commit automatically.
 *
 * You shouldn't subclass COUndoTrack.
 */
@interface COUndoTrack : NSObject <COTrack>
{
	@private
    COUndoTrackStore *_store;
    NSString *_name;
	NSMutableArray *_nodesOnCurrentUndoBranch;
	NSMutableDictionary *_commandsByUUID;
	COEditingContext *_editingContext;
	NSMutableDictionary *_trackStateForName;
	
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
 * -[COEditingContext commmitWithIdentitifer:metadata:undoTrack:error:], 
 * otherwise the commit raises an exception.
 *
 * See -editingContext.
 */
+ (COUndoTrack *)trackForPattern: (NSString *)aPattern
              withEditingContext: (COEditingContext *)aContext;


/** @taskunit Basic Properties */


/**
 * The unique name bound to the track.
 */
@property (nonatomic, readonly) NSString *name;
/**
 * The editing context that is changed if -undo, -redo or -setCurrentNode: are 
 * called.
 */
@property (nonatomic, readonly) COEditingContext *editingContext;
/**
 * If set, COUndoTrack will add these keys/values to the revision
 * metadata when it commits a revision in response to -undo/-redo, 
 * or -undoNode:/-redoNode:.
 *
 * For example, use this if you want to record the user's name
 * in revisions they commit using the undo track.
 */
@property (nonatomic, readwrite, copy) NSDictionary *customRevisionMetadata;

/** @taskunit Clearing and Coalescing Commands */


/**
 * Discards all the commands.
 */
- (void)clear;
/**
 * Tells the receiver to put the next recorded commands in the same command 
 * group until -endCoalescing is called.
 *
 * For the next commits, the track won't create a command group per commit.
 *
 * By bracketing multiple commits with -beginCoalescing and -endCoalescing, 
 * these multiple commits can be recorded as a single one (i.e. a single 
 * COCommandGroup) on the track.
 *
 * Calling -beginCoalescing doesn't change the rules for the branch revision 
 * creation on commit. 
 *
 * See also -endCoalescing.
 */
- (void)beginCoalescing;
/** 
 * Tells the receiver to group the next recorded commands per commit.
 *
 * For the next commits, the track will create a command group per commit.
 *
 * See also -beginCoalescing.
 */
- (void)endCoalescing;
/**
 * Returns whether coalescing is active.
 */
- (BOOL)isCoalescing;


/** @taskunit Convenience */


/**
 * Returns a localized menu item title describing the command to undo.
 */
- (NSString *) undoMenuItemTitle;
/**
 * Returns a localized menu item title describing the command to redo.
 */
- (NSString *) redoMenuItemTitle;


/** @taskunit Divergent Commands */


/**
 * Returns all commands ordered by commit order.
 *
 * See also -[COCommandGroup sequenceNumber].
 */
- (NSArray *) allCommands;
/**
 * Returns all commands that are children of the given node (the order is 
 * undefined).
 */
- (NSArray *) childrenOfNode: (id<COTrackNode>)aNode;


/** @taskunit Framework Private */


/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Saves the command on disk and remembers it as the current command.
 *
 * See also -currentCommand.
 */
- (void) recordCommand: (COCommandGroup *)aCommand;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the undo track store used by this track.
 */
@property (nonatomic, readonly) COUndoTrackStore *store;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns a cached command group, or attempts to load it from the store if
 * not present in memory.
 *
 * If the command has been deleted, returns nil.
 */
- (COCommandGroup *) commandForUUID: (ETUUID*)aUUID;

@end
