/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

NS_ASSUME_NONNULL_BEGIN

@interface COEndOfUndoTrackPlaceholderNode : NSObject <COTrackNode>

+ (COEndOfUndoTrackPlaceholderNode *)sharedInstance;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
