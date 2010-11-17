#import <Cocoa/Cocoa.h>
#import "COCommit.h"
#import "COObject.h"

/**
 * A history track is a view on the database of commits, presenting
 * them as a history graph. It is not persistent or cached in any way, however
 * this may be done for performance later. 
 *
 */
@interface COHistoryView : NSObject
{

}


- (CONamedBranch*)namedBranch;
- (void)setNamedBranch: (CONamedBranch*)namedBranch;

- (COCommit*)tipNode;
- (COCommit*)currentNode;

/**
 * Convience method moves the current node one node closer to the tip, on
 * the path defined by starting at the tipNode and following parent pointers.
 */
- (COCommit*)moveCurrentNodeForward;
/** 
 * Same as above, but moves one node away from the tip.
 */
- (COCommit*)moveCurrentNodeBackward;

- (void)setCurrentNode: (COCommit*)node;

@end
