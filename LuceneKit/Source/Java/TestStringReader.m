#include "LCStringReader.h"
#include <UnitKit/UnitKit.h>

@interface TestStringReader: NSObject <UKTest>
@end

@implementation TestStringReader
- (void) testStringReader
{
        LCStringReader *reader = [[LCStringReader alloc] initWithString: @"This is a reader"];
        UKTrue([reader ready]);
        UKIntsEqual('T', [reader read]);
        unichar buf[4]; 
        [reader read: buf length: 3];
        UKIntsEqual('s', buf[2]);
        UKIntsEqual(' ', [reader read]);
        UKIntsEqual(8, [reader skip: 8]);
        UKIntsEqual('d', [reader read]); 
        UKIntsEqual(2, [reader read: buf length: 3]);
        UKIntsEqual('r', buf[1]);
        UKIntsEqual(0, [reader skip: 3]);
}
@end

