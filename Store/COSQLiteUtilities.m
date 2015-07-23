/*
    Copyright (C) 2015 Quentin Mathe

    Date:  July 2015
    License:  MIT  (see COPYING)
 */

#import "COSQLiteUtilities.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

NSDictionary *pageStatisticsForDatabase(FMDatabase *db)
{
	NSNumber *freelistCount = [db numberForQuery: @"PRAGMA freelist_count"];
	NSNumber *pageCount = [db numberForQuery: @"PRAGMA page_count"];
	NSNumber *pageSize = [db numberForQuery: @"PRAGMA page_size"];
	
	return @{ @"freelist_count" : freelistCount,
	          @"page_count" : pageCount,
	          @"page_size" : pageSize };

}
