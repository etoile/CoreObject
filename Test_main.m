#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <UnitKit/UKRunner.h>
#import <UnitKit/UKTestHandler.h>
#import "TestCommon.h"

int main (int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	UKRunner *runner = [UKRunner new];

	[[UKTestHandler handler] setQuiet: YES];

	[runner runTestsInBundle: [NSBundle mainBundle] principalClass: [TestCommon class]];
	[runner reportTestResults];
	
	[runner release];
    [pool drain];
    return 0;
}
