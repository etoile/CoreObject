/*
	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2010
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "ETStackTraceRecorder.h"
#import "ETCollection.h"
#import "EtoileCompatibility.h"

@interface TestStackTraceRecorder : NSObject <UKTest>
@end

@implementation TestStackTraceRecorder

- (void) testRecordStackTrace
{
	UKTrue([[self recordedStackTraces] isEmpty]);

	[self recordStackTrace];

	UKIntsEqual(1, [[self recordedStackTraces] count]);
	ETStackTrace *trace1 = [[self recordedStackTraces] firstObject];
	UKTrue([trace1 numberOfFrames] > 1);

	[self recordStackTrace];

	UKIntsEqual(2, [[self recordedStackTraces] count]);
	ETStackTrace *trace2 = [[self recordedStackTraces] lastObject];
	UKObjectsNotEqual(trace1, trace2);
	UKTrue([trace2 numberOfFrames] > 1);
}

- (void) testRecordStackTraceOnAllocation
{
	ETStackTraceRecorder *recorder = [ETStackTraceRecorder sharedInstance];
 
	[recorder enableAllocationRecordingForClass: [NSObject class]];

	id obj1 = AUTORELEASE([NSObject new]);
	id obj2 = AUTORELEASE([NSObject new]);
	id obj3 = [NSString string];

	[recorder disableAllocationRecordingForClass: [NSObject class]];

	id obj4 = AUTORELEASE([NSObject new]);

	UKIntsEqual(1, [[recorder recordedStackTracesForObject: obj1] count]);
	UKIntsEqual(1, [[recorder recordedStackTracesForObject: obj2] count]);	
	UKTrue([[recorder recordedStackTracesForObject: obj3] isEmpty]);	
	UKTrue([[recorder recordedStackTracesForObject: obj4] isEmpty]);	
}

@end
