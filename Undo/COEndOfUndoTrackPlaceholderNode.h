#import <CoreObject/CoreObject.h>

@interface COEndOfUndoTrackPlaceholderNode : NSObject <COTrackNode>

+ (COEndOfUndoTrackPlaceholderNode *) sharedInstance;

@end