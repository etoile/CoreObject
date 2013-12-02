#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <UnitKit/UKRunner.h>
#import <UnitKit/UKTestHandler.h>
#import "TestCommon.h"

int main (int argc, const char *argv[])
{
    @autoreleasepool {
		UKRunner *runner = [UKRunner new];

		[[UKTestHandler handler] setQuiet: YES];

		NSDate *startDate = [NSDate date];
		
		[runner runTestsInBundle: [NSBundle mainBundle] principalClass: [EditingContextTestCase class]];
		[runner reportTestResults];
		
		printf("Took %d ms\n", (int)([[NSDate date] timeIntervalSinceDate: startDate] * 1000));
    }
    return 0;
}
