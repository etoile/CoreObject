/*
    Copyright (C) 2014 Quentin Mathe

    Date:  July 2014
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE

/**
 * @group iOS
 * @abstract A fake distributed notification center that operates locally.
 *
 * This makes possible to support NSDistributedNotificationCenter API on iOS.
 *
 * On macOS, we use it to keep multiple store instances (using the same UUID)
 * in sync, accross processes and inside the current process. On iOS, this is
 * the same, except we don't support the 'accross processes' case.
 *
 * Note: A store cannot be accessed by multiple applications on iOS, due to the
 * sandboxing restrictions.
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

/**
 * AppStore approval process treats NSDistributedNotificationCenter as a private
 * API, so we use another name internally.
 */
@compatibility_alias NSDistributedNotificationCenter CODistributedNotificationCenter;

#endif
