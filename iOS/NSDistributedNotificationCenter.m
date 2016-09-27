/*
    Copyright (C) 2014 Quentin Mathe

    Date:  July 2014
    License:  MIT  (see COPYING)
 */

#import "NSDistributedNotificationCenter.h"

/**
 * @group iOS
 * @abstract A fake distributed notification center that operates locally.
 *
 * This makes possible to support NSDistributedNotificationCenter API on iOS.
 *
 * On Mac OS X, we use it to keep multiple store instances (using the same UUID)
 * in sync, accross processes and inside the current process. On iOS, this is
 * the same, except we don't support the 'accross processes' case.
 *
 * Note: A store cannot be accessed by multiple applications on iOS, due to the
 * sandboxing restrictions.
 *
 * See also COSQLiteStore and COUndoTrackStore.
 **/
@implementation CODistributedNotificationCenter

static CODistributedNotificationCenter *defaultCenter = nil;

+ (void)initialize
{
    if ([self class] != self)
        return;

    defaultCenter = [[self alloc] init];
}

+ (CODistributedNotificationCenter *)defaultCenter
{
    return defaultCenter;
}

- (void)postNotificationName: (NSString *)aName
                      object: (NSString *)aSender
                    userInfo: (NSDictionary *)userInfo
          deliverImmediately: (BOOL)deliverImmediately
{
    [self postNotificationName: aName object: aSender userInfo: userInfo];
}

@end
