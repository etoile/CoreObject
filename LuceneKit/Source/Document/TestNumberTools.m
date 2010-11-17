#include <UnitKit/UnitKit.h>
#include "LCNumberTools.h"

@interface TestNumberTools: NSObject <UKTest>
@end

@implementation TestNumberTools
- (void) subtestTwoLongs: (long long) i : (long long) j
{
	// convert to strings
	NSString *a = [NSString stringWithLongLong: i];
	NSString *b = [NSString stringWithLongLong: j];
	
	// are they the right length? STR_SIZE+PREFIX
	UKIntsEqual(STR_SIZE+1, [a length]);
	UKIntsEqual(STR_SIZE+1, [b length]);
	
	// are they the right order?
	if (i < j) {
		UKTrue([a caseInsensitiveCompare: b] == NSOrderedAscending);
		//assertTrue(a.compareTo(b) < 0);
	} else if (i > j) {
		UKTrue([a caseInsensitiveCompare: b] == NSOrderedDescending);
		//assertTrue(a.compareTo(b) > 0);
	} else {
		UKTrue([a caseInsensitiveCompare: b] == NSOrderedSame);
		//assertEquals(a, b);
	}
	
	// can we convert them back to longs?
	long long i2 = [a longLongValue];
	long long j2 = [b longLongValue];
	
	UKTrue(i == i2);
	UKTrue(j == j2);
}

- (void) testNearZero
{
	int i, j;
	for (i = -100; i <= 100; i++) {
		for (j = -100; j <= 100; j++) {
			[self subtestTwoLongs: i : j];
		}
	}
}

- (void) testMax
{
	long long i;
	for(i = ULONG_MAX; i > ULONG_MAX-10000; i--)
    {
		[self subtestTwoLongs: i : i-1];
    }
}

- (void) testMin
{
	long long i;
	for(i = -1*ULONG_MAX; i < -1*ULONG_MAX+10000; i++)
    {
		[self subtestTwoLongs: i : i+1];
    }
}

@end
