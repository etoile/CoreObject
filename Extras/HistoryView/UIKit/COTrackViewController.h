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
 * By default, this is background color for all nodes before the current node.
 *
 * The current node background color is based on this color too.
 *
 * See -suggestedColorForNode:.
 */
@property (nonatomic, retain) UIColor *pastColor;
/**
 * The color used to indicate the future history.
 *
 * By default, this is background color for all nodes after the current node.
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
 * and the background color to -suggestedColorForNode:.
 *
 * Can be overriden to return a custom cell.
 */
- (UITableViewCell *)makeCellForNode: (id <COTrackNode>)node;


/** @taskunit Undo and Redo */


/**
 * See -[COTrack undo].
 */
- (IBAction)undo;
/**
 * See -[COTrack redo].
 */
- (IBAction)redo;


@end
