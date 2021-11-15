/*
    Copyright (C) 2014 Quentin Mathe

    Date:  July 2014
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @group Utilities
 * @abstract Distributed notification center compatible with sandboxing.
 * 
 * When sandboxing is enabled, posting a distributed notification results 
 * in a normal notification.
 *
 * For non-sandboxed applications on macOS, we use 
 * NSDistributedNotificationCenter to keep multiple store instances (using the 
 * same UUID) in sync, accross processes and inside the current process. For 
 * sandboxed applications on iOS or macOS, this is the same, except we don't 
 * support the 'accross processes' case.
 * 
 * We cannot ignore distributed notifications in a sandboxed app, because we 
 * support keeping in sync two editing contexts backed by two distinct stores 
 * objects with the same UUID.
 *
 * See also COSQLiteStore and COUndoTrackStore.
 **/
@interface CODistributedNotificationCenter : NSObject
/**
 * Returns the default distributed notification center.
 */
+ (CODistributedNotificationCenter *)defaultCenter;
/** 
 * Adds an observer for the given selector, notification name and object identifier.
 */
- (void)addObserver: (id)observer 
           selector: (SEL)aSelector 
               name: (nullable NSNotificationName)aName 
             object: (nullable NSString *)anObject;
/**
 * Removes an observer.
 */
- (void)removeObserver: (id)observer;
/**
 * Posts a notification with the given sender and info.
 *
 * deliverImmediately is ignored, and considered as YES all the time.
 */
- (void)postNotificationName: (nullable NSNotificationName)aName
                      object: (nullable NSString *)aSender
                    userInfo: (nullable NSDictionary *)userInfo
          deliverImmediately: (BOOL)deliverImmediately;
@end

NS_ASSUME_NONNULL_END
