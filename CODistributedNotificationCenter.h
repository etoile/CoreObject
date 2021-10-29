/*
    Copyright (C) 2014 Quentin Mathe

    Date:  July 2014
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

/**
 * @group Utilities
 * @abstract Distributed notification center compatible with sandboxing.
 * 
 * When sandboxing is enabled, posting a notification does nothing.
 *
 * For non-sandboxed applications on macOS, we use 
 * NSDistributedNotificationCenter to keep multiple store instances (using the 
 * same UUID) in sync, accross processes and inside the current process. For 
 * sandboxed applications on iOS or macOS, this is the same, except we don't 
 * support the 'accross processes' case.
 *
 * See also COSQLiteStore and COUndoTrackStore.
 **/
@interface CODistributedNotificationCenter : NSNotificationCenter
/**
 * Returns the default distributed notification center.
 */
+ (CODistributedNotificationCenter *)defaultCenter;
/**
 * Posts a notification with the given sender and info.
 *
 * deliverImmediately is ignored, and considered as YES all the time.
 */
- (void)postNotificationName: (NSString *)aName
                      object: (NSString *)aSender
                    userInfo: (NSDictionary *)userInfo
          deliverImmediately: (BOOL)deliverImmediately;
@end
