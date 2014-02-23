#import "BenchmarkCommon.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation BenchmarkCommon

+ (NSData *) randomData1K
{
	unsigned char random1K[1024];
	for (int i=0; i<1024; i++)
	{
		random1K[i] = (unsigned char)rand();
	}
	return [NSData dataWithBytes: random1K length: 1024];
}

+ (void) insertRandomData1K: (FMDatabase *)db
{
	NSData *data = [self randomData1K];
	ETAssert(1024 == [data length]);
	ETAssert(([db executeUpdate: @"INSERT INTO test VALUES(?)", data]));
}

+ (NSTimeInterval) timeToCommit1KUsingSQLite
{
	static NSTimeInterval result;
	if (result == 0)
	{
		FMDatabase *tempDatabase = [FMDatabase databaseWithPath:
									[NSTemporaryDirectory() stringByAppendingPathComponent: [[ETUUID UUID] stringValue]]];
		ETAssert([tempDatabase open]);
		ETAssert([[tempDatabase stringForQuery: @"PRAGMA journal_mode=WAL"] isEqual: @"wal"]);
		ETAssert([tempDatabase executeUpdate: @"CREATE TABLE test(blob BLOB)"]);
		
		// Warm up
		[self insertRandomData1K: tempDatabase];
		
		// Make 100 commits and take the mean
		NSDate *startDate = [NSDate date];
		for (int i=0; i<100; i++)
		{
			[tempDatabase beginTransaction];
			[self insertRandomData1K: tempDatabase];
			[tempDatabase commit];
		}
		NSTimeInterval timeFor100Commits = [[NSDate date] timeIntervalSinceDate: startDate];
		result = timeFor100Commits / 100.0;
		
		ETAssert(101 == [tempDatabase intForQuery: @"SELECT COUNT(*) FROM test"]);
	}
	return result;
}

@end
