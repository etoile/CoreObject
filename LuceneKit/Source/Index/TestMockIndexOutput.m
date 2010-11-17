#include "GNUstep.h"
#include "LCIndexOutput.h"
#include <UnitKit/UnitKit.h>

@interface TestMockIndexOutput: LCIndexOutput <UKTest>
{
	NSMutableData *data;
	unsigned long long pointer;
}
@end

@implementation TestMockIndexOutput
- (id) init
{
	self = [super init];
	data = [[NSMutableData alloc] init];
	pointer = 0;
	return self;
}

- (void) writeByte: (char) b
{
	NSData *d = [NSData dataWithBytes: &b length: 1];
	[self writeBytes: d length: 1];
}

- (void) writeBytes: (NSData *) b length: (int) len
{
	NSRange r = NSMakeRange(0, len);
	if (pointer == [data length]) /* The end of file */
		[data appendData: [b subdataWithRange: r]];
	else if (pointer < [data length]) /* within file */
    {
		NSData *new1 = [data subdataWithRange: NSMakeRange(0, pointer)];
		NSData *new2 = nil;
		if (pointer+len < [data length])
			new2 = [data subdataWithRange: NSMakeRange(pointer+len, [data length]-pointer-len)];
		
        [data setLength: 0];
        [data appendData: new1];
        [data appendData: [b subdataWithRange: r]];
        if (new2) [data appendData: new2];
		//        NSLog(@"%@", [data subdataWithRange: NSMakeRange(0, 10)]);
	}
	pointer += len;
}

- (void) flush {}
- (void) close {}
- (unsigned long long) offsetInFile {return pointer;}
- (void) seekToFileOffset: (unsigned long long) pos
{
	pointer = pos;
}

- (unsigned long long) length
{
	return [data length];
}

- (void) testWriteInt
{
	[self writeInt: 1];
	char *buf = (char *)[data bytes];
	UKIntsEqual(0, buf[0]);
	UKIntsEqual(0, buf[1]);
	UKIntsEqual(0, buf[2]);
	UKIntsEqual(1, buf[3]);
	[self writeInt: -1];
	buf = (char *)[data bytes];
	/* Not sure it is the correct result */
	UKIntsEqual((char)0xff, buf[4]);
	UKIntsEqual((char)0xff, buf[5]);
	UKIntsEqual((char)0xff, buf[6]);
	UKIntsEqual((char)0xff, buf[7]);
}

- (void) testWriteVInt
{
	[self writeVInt: 128];
	char *buf = (char *)[data bytes];
	UKIntsEqual((char)0x80, buf[0]);
	UKIntsEqual((char)0x01, buf[1]);
	[self writeVInt: 16383];
	buf = (char *)[data bytes];
	UKIntsEqual((char)0xFF, buf[2]);
	UKIntsEqual((char)0x7F, buf[3]);
	[self writeVInt: 16384];
	buf = (char *)[data bytes];
	UKIntsEqual((char)0x80, buf[4]);
	UKIntsEqual((char)0x80, buf[5]);
	UKIntsEqual((char)0x01, buf[6]);
	[self writeVInt: 16385];
	buf = (char *)[data bytes];
	UKIntsEqual((char)0x81, buf[7]);
	UKIntsEqual((char)0x80, buf[8]);
	UKIntsEqual((char)0x01, buf[9]);
}

@end
