#include "LCPriorityQueue.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>

@interface LCIntegerQueue: LCPriorityQueue <UKTest>
@end

@implementation LCIntegerQueue
- (void) doTestPriorityQueue: (int) count
{
	self = [self initWithSize: count];
	srandom((unsigned long)[[NSDate date] timeIntervalSinceReferenceDate]);
	int sum = 0, sum2 = 0;
	int i, next, prev;
	
	for(i = 0; i < count; i++)
    {
		next = (int)random();
		sum += next;
		[self put: [NSNumber numberWithInt: next]];
    }
	
	prev = -1;
	for(i = 0; i < count; i++)
    {
		next = [[self pop] intValue];
		sum2 += next;
		UKTrue(prev < next);
		if (prev >= next)
			NSLog(@"prev %d, next %d", prev, next);
		prev = next;
    }
	UKIntsEqual(sum, sum2);
}

- (void) testPriorityQueue
{
	[self doTestPriorityQueue: 10000];
}

- (void) testClear
{
	self = [self initWithSize: 3];
	[self put: [NSNumber numberWithInt: 2]];
	[self put: [NSNumber numberWithInt: 3]];
	[self put: [NSNumber numberWithInt: 1]];
	UKIntsEqual(3, [self size]);
	[self removeAllObjects];
	UKIntsEqual(0, [self size]);
}

- (void) testFixedSize
{
	self = [self initWithSize: 3];
	[self insert: [NSNumber numberWithInt: 2]];
	[self insert: [NSNumber numberWithInt: 3]];
	[self insert: [NSNumber numberWithInt: 1]];
	[self insert: [NSNumber numberWithInt: 5]];
	[self insert: [NSNumber numberWithInt: 7]];
	[self insert: [NSNumber numberWithInt: 1]];
	UKIntsEqual(3, [self size]);
	UKIntsEqual(3, [[self top] intValue]);
}

@end

