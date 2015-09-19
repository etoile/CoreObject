/*
    Copyright (C) 2015 Quentin Mathe

    Date:  July 2015
    License:  MIT  (see COPYING)
 */

#import "COSQLiteUtilities.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#ifndef DISPATCH_CURRENT_QUEUE_LABEL
#	define DISPATCH_CURRENT_QUEUE_LABEL (dispatch_get_current_queue())
#endif

void dispatch_sync_now(dispatch_queue_t queue, dispatch_block_t block) {
	const char *currentQueueLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);

	if (strcmp(dispatch_queue_get_label(queue), currentQueueLabel) == 0)
	{
		block();
	}
	else {
		dispatch_sync(queue, block);
	}
}

NSDictionary *pageStatisticsForDatabase(FMDatabase *db)
{
	NSNumber *freelistCount = [db numberForQuery: @"PRAGMA freelist_count"];
	NSNumber *pageCount = [db numberForQuery: @"PRAGMA page_count"];
	NSNumber *pageSize = [db numberForQuery: @"PRAGMA page_size"];
	
	return @{ @"freelist_count" : freelistCount,
	          @"page_count" : pageCount,
	          @"page_size" : pageSize };

}
