#include "LCBitVector.h"
#include "LCRAMDirectory.h"
#include <UnitKit/UnitKit.h>
#include "GNUstep.h"

@interface TestBitVector: NSObject <UKTest>
@end

@implementation TestBitVector

- (void) doTestConstructOfSize: (int) n
{
	LCBitVector *vector = [[LCBitVector alloc] initWithSize: n];
	UKIntsEqual(n, [vector size]);
}

- (void) doTestGetSetVectorOfSize: (int) n
{
	LCBitVector *vector = [[LCBitVector alloc] initWithSize: n];
	int i;
	for(i = 0; i < [vector size]; i++) 
    {
		UKFalse([vector bit: i]);
		[vector setBit: i];
		UKTrue([vector bit: i]);
    }
}

- (void) doTestClearVectorOfSize: (int) n
{
	LCBitVector *vector = [[LCBitVector alloc] initWithSize: n];
	int i;
	for(i = 0; i < [vector size]; i++) 
    {
		UKFalse([vector bit: i]);
		[vector setBit: i];
		UKTrue([vector bit: i]);
		[vector clearBit: i];
		UKFalse([vector bit: i]);
    }
}

- (void) doTestCountVectorOfSize: (int) n 
{
	LCBitVector *vector = [[LCBitVector alloc] initWithSize: n];
	int i;
	for(i = 0; i < [vector size]; i++) 
    {
		UKFalse([vector bit: i]);
		UKIntsEqual(i, [vector count]);
		[vector setBit: i];
		UKTrue([vector bit: i]);
		UKIntsEqual(i+1, [vector count]);
    }
	
	vector = [[LCBitVector alloc] initWithSize: n];
	for(i = 0; i < [vector size]; i++) 
    {
		UKFalse([vector bit: i]);
		UKIntsEqual(0, [vector count]);
		[vector setBit: i];
		UKTrue([vector bit: i]);
		UKIntsEqual(1, [vector count]);
		[vector clearBit: i];
		UKFalse([vector bit: i]);
		UKIntsEqual(0, [vector count]);
    }
}

- (BOOL) doCompare: (LCBitVector *) vector: (LCBitVector *) other
{
	int i;
	for(i = 0; i < [vector size]; i++)
	{
		// bits must be equal
		if([vector bit: i] != [other bit: i]) 
		{
			return NO;
		}
	}
	return YES;
}

- (void) doTestWriteRead: (int) n
{
	id <LCDirectory> d = [[LCRAMDirectory alloc] init];
	LCBitVector *compare;
	LCBitVector *vector = [[LCBitVector alloc] initWithSize: n];
	// test count when incrementally setting bits
	int i;
	for(i = 0; i < [vector size]; i++) 
    {
		UKFalse([vector bit: i]);
		UKIntsEqual(i, [vector count]);
		[vector setBit: i];
		UKTrue([vector bit: i]);
		UKIntsEqual(i+1, [vector count]);
		[vector writeToDirectory: d name: @"TESTBV"];
		
		compare = [[LCBitVector alloc] initWithDirectory: d
												 name: @"TESTBV"];
		// compare bit vectors with bits set incrementally
		UKTrue([self doCompare: vector: compare]);
		RELEASE(compare);
    }
	RELEASE(d);
}

- (void) testAll
{
	[self doTestConstructOfSize: 8];
	[self doTestConstructOfSize: 20];
	[self doTestConstructOfSize: 100];
	[self doTestConstructOfSize: 1000];
	
	[self doTestGetSetVectorOfSize: 8];
	[self doTestGetSetVectorOfSize: 20];
	[self doTestGetSetVectorOfSize: 100];
	[self doTestGetSetVectorOfSize: 1000];
	
	[self doTestClearVectorOfSize: 8];
	[self doTestClearVectorOfSize: 20];
	[self doTestClearVectorOfSize: 100];
	[self doTestClearVectorOfSize: 1000];
	
	[self doTestCountVectorOfSize: 8];
	[self doTestCountVectorOfSize: 20];
	[self doTestCountVectorOfSize: 100];
	[self doTestCountVectorOfSize: 1000];
}

- (void) testWriteRead
{
	[self doTestWriteRead: 8];
	[self doTestWriteRead: 20];
	[self doTestWriteRead: 100];
	[self doTestWriteRead: 1000];
}

@end

