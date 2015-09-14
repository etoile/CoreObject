/**
	Copyright (C) 2015 Quentin Mathe

	Date:  January 2015
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COCocoaTouchCompatibility.h>
#import <EtoileFoundation/EtoileFoundation.h>

@protocol COTrack, COTrackNode;

@interface COTrackViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate>
{
	@private
	id <COTrack> _track;
	UIColor *_pastColor;
	UIColor *_futureColor;
	NSIndexPath *_checkedIndexPath;
}


/** @taskunit Presented Track and Nodes */


/**
 * The track whose nodes are presented in the table view.
 */
@property (nonatomic, retain) id <COTrack> track;
/**
 * Returns the node at the given index path in the table view.
 *
 * The nodes returned by -[COTrack nodes] appear usually in the table view in
 * their reverse order (the first row being the most recent node).
 */
- (id <COTrackNode>)nodeForRowAtIndexPath: (NSIndexPath *)indexPath;


/** @taskunit Customizing Appearance */


/**
 * The color used to indicate the past history.
 *
 * By default, this is the text color for all nodes before the current node.
 *
 * The current node text color is based on this color too.
 *
 * See -suggestedColorForNode:.
 */
@property (nonatomic, retain) UIColor *pastColor;
/**
 * The color used to indicate the future history.
 *
 * By default, this is the text color for all nodes after the current node.
 *
 * See -suggestedColorForNode:.
 */
@property (nonatomic, retain) UIColor *futureColor;
/**
 * Returns either -pastColor or -futureColor based on where the node sits 
 * relative to -[COTrack currentNode].
 *
 * Can be overriden to return a custom color.
 */
- (UIColor *)suggestedColorForNode: (id <COTrackNode>)node;
/**
 * Returns a new or reused cell ready to presented in the table view.
 *
 * The returned cell must be created with 
 * -[UITableView dequeueReusableCellWithIdentifier:].
 *
 * By default, the cell label is set to -[COTrackNode localizedShortDescription]
 * and the text color to -suggestedColorForNode:.
 *
 * Can be overriden to return a custom cell.
 */
- (UITableViewCell *)makeCellForNode: (id <COTrackNode>)node;
/**
 * Adds a visual indicator to the row representing the current node.
 *
 * Will be called after -uncheckRowAtIndexPath:.
 *
 * You shouldn't call this method, but override it to add a custom visual
 * indicator set on the row.
 *
 * The default indicator is a checkmark.
 */
- (void)checkRow: (UITableViewCell *)cell;
/**
 * Removes the visual indicator from the row representing the current node.
 *
 * Will be called before -checkRowAtIndexPath:.
 *
 * You shouldn't call this method, but override it to remove a custom visual
 * indicator set on the row.
 *
 * The default indicator is a checkmark.
 */
- (void)uncheckRow: (UITableViewCell *)cell;


/** @taskunit Undo and Redo */


/**
 * See -[COTrack undo].
 *
 * Can be overriden to record a branch undo on an undo track.
 */
- (IBAction)undo;
/**
 * See -[COTrack redo].
 *
 * Can be overriden to record a branch redo on an undo track.
 */
- (IBAction)redo;
/**
 * Tells the user changed the selection by tapping a row, and changes the 
 * current node to the given node.
 *
 * See -[COTrack setCurrentNode:].
 *
 * Can be overriden to record a branch current revision change on an undo track.
 */
- (void)didSelectNode: (id <COTrackNode>)aNode;


/** @taskunit Reacting to Track Changes */


/**
 * Tells the receiver that the track content or current node changed.
 *
 * Can be overriden to update the UI (usually to control when undo and redo 
 * buttons are enabled), but the superclass implementation must be called.
 *
 * The notification argument is a ETCollectionDidUpdateNotification or nil.
 */
- (void)trackDidUpdate: (NSNotification *)notif;

@end
