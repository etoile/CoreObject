#include "NSString+Additions.h"
#include <UnitKit/UnitKit.h>

@interface NSStringAdditions: NSObject <UKTest>
@end

@implementation NSStringAdditions
- (void) testDifference
{
	NSString *test1 = @"test";
	NSString *test2 = @"testing";
	
	int result = [test1 positionOfDifference: test2];
	UKTrue(result == 4);
	
	test2 = @"foo";
	result = [test1 positionOfDifference: test2];
	UKTrue(result == 0);
	
	test2 = @"test";
	result = [test1 positionOfDifference: test2];
	UKTrue(result == 4);
}
@end


