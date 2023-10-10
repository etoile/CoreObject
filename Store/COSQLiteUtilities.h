/**
    Copyright (C) 2015 Quentin Mathe

    Date:  July 2015
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#include <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

void dispatch_sync_now(dispatch_queue_t queue, dispatch_block_t block);

NSDictionary<NSString *, NSNumber *> *pageStatisticsForDatabase(FMDatabase *db);

NS_ASSUME_NONNULL_END
