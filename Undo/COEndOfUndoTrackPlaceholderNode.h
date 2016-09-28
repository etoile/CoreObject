/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COEndOfUndoTrackPlaceholderNode : NSObject <COTrackNode>

+ (COEndOfUndoTrackPlaceholderNode *)sharedInstance;

@end
