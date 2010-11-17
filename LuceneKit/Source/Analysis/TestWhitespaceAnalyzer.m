#include "LCWhitespaceAnalyzer.h"
#include "LCWhitespaceTokenizer.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>
#include "TestAnalyzer.h"

@interface TestWhitespaceAnalyzer: NSObject <UKTest>
@end

@implementation TestWhitespaceAnalyzer

- (void) testWhitespaceAnalyzer
{
	NSString *s = @"This is a beautiful day!";
	NSArray *a = [s componentsSeparatedByString: @" "];
	LCWhitespaceAnalyzer *analyzer = [[LCWhitespaceAnalyzer alloc] init];
	[analyzer compare: s and: a with: analyzer];
}

@end
