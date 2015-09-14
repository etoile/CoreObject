/**
    Copyright (C) 2015 Quentin Mathe

    Date:  July 2015
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#include <dispatch/dispatch.h>

void dispatch_sync_now(dispatch_queue_t queue, dispatch_block_t block);

NSDictionary *pageStatisticsForDatabase(FMDatabase *db);
