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
		
		[runner runTestsInBundle: [NSBundle mainBundle] principalClass: [EditingContextTestCase class]];
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

	// TODO: Maybe count up the number of leaked COSQLiteStore instances at this
	// point.
	//
	// As of 2014-01-24, there are 3 leaked stores:
	//
	//  - In TestSynchronizer, -testBasicServerRevert and -testBasicClientRevert each leak a store.
	//    (I don't understand why, but they're not so serious because
	//     they only happen when throwing an exception in response to incorrect API usage.)
	//
	//  - +[COUndoStackStore defaultStore] intentionally leaks a database connection.

	return status;
}
