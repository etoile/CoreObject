/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <UnitKit/UKRunner.h>
#import <UnitKit/UKTestHandler.h>
#import "TestCommon.h"

int main (int argc, const char *argv[])
{
	int status = 0;
	
    @autoreleasepool {
		UKRunner *runner = [UKRunner new];

		UKTestHandler *handler = [UKTestHandler handler];
		[handler setQuiet: YES];

		NSDate *startDate = [NSDate date];
		
		[runner runTestsWithClassNames: nil principalClass: [EditingContextTestCase class]];
		[runner reportTestResults];
		
		printf("Took %d ms\n", (int)([[NSDate date] timeIntervalSinceDate: startDate] * 1000));

		if ([handler exceptionsReported] > 0 || [handler testsFailed] > 0)
		{
			status = 1;
		}
	}

	// Run a runloop so we handle any outstanding notifications, so
	// we can check for leaks afterwards.
	
	@autoreleasepool
	{
		NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
		[runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	}

#ifdef FMDatabase_DEBUG

	// Count up the number of open sqlite database connections at this
	// point.
	//
	// As of 2014-01-24, there are 3 open connections:
	//
	//  - In TestSynchronizer, -testBasicServerRevert and -testBasicClientRevert each leak a store.
	//    (I don't understand why, but they're not so serious because
	//     they only happen when throwing an exception in response to incorrect API usage.)
	//
	//  - +[COUndoStackStore defaultStore] intentionally opens and never closes a database connection
	//    to the ~/Library/CoreObject/Undo/undo.sqlite database

	@autoreleasepool
	{
		[FMDatabase logOpenDatabases];

		const int expectedOpenDatabases = 3;
		if ([FMDatabase countOfOpenDatabases] > expectedOpenDatabases)
		{
			NSLog(@"ERROR: Expected only %d SQLite database connections to still be open.", expectedOpenDatabases);
			status = 1;
		}
	}

#endif

	return status;
}
