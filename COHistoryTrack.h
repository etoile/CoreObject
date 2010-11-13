#import <Cocoa/Cocoa.h>
#import "COHistoryNode.h"
#import "COObject.h"

/**
 * A history track is a view on the database of commits, presenting
 * them as a history graph. It is not persistent or cached in any way, however
 * this may be done for performance later. 
 *
 */
@interface COHistoryTrack : NSObject
{

}

+ (COHistoryTrack*)globalHistoryTrack;
+ (COHistoryTrack*)historyTrackForObjectsWithUUIDs: (NSArray*)uuids;
+ (COHistoryTrack*)historyTrackForContainer: (COObject*)container;

- (COHistoryNode*)tipNode;
- (COHistoryNode*)currentNode;

/**
 * Convience method moves the current node one node closer to the tip, on
 * the path defined by starting at the tipNode and following parent pointers.
 */
- (COHistoryNode*)moveCurrentNodeForward;
/** 
 * Same as above, but moves one node away from the tip.
 */
- (COHistoryNode*)moveCurrentNodeBackward;

- (void)setCurrentNode: (COHistoryNode*)node;

@end
