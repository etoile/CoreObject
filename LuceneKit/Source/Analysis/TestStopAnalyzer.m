#include "LCStopAnalyzer.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>
#include "TestAnalyzer.h"

@interface TestStopAnalyzer: NSObject <UKTest>
@end

@implementation TestStopAnalyzer

- (void) testStopAnalyzer
{
	NSString *s = @"This is a beautiful day!";
	NSArray *a = [NSArray arrayWithObjects: @"beautiful", @"day", nil];
	LCStopAnalyzer *analyzer = [[LCStopAnalyzer alloc] init];
	[analyzer compare: s and: a with: analyzer];
}

@end

