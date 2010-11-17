#include "GNUstep.h"
#include "LCIndexInput.h"
#include <UnitKit/UnitKit.h>

@interface TestMockIndexInput: LCIndexInput <UKTest>
{
	NSData *data;
	unsigned long long pointer;
}
- (id) initWithData: (NSData *) data;
@end

@implementation TestMockIndexInput
- (id) initWithData: (NSData *) d
{
	self = [super init];
	ASSIGN(data, d);
	pointer = 0;
	return self;
}

- (char) readByte
{
	char *ch = (char *) [data bytes];
	return ch[pointer++];
}

- (void) readBytes: (NSMutableData *) b
			offset: (int) offset
			length: (int) length
{
	int len;
	if (pointer+length > [data length])
		len = pointer + length - [data length];
	else
		len = length;
	
	NSRange r = NSMakeRange(pointer, len);
	NSData *sub = [data subdataWithRange: r];
	if ([b length] < offset + length)
	{
		[b setLength: (offset + length)];
	}
	r = NSMakeRange(offset, len);
	[b replaceBytesInRange: r withBytes: [sub bytes]];
	pointer += len;
}

- (void) close {}

- (unsigned long long) offsetInFile
{
	return pointer;
}

- (void) seekToFileOffset: (unsigned long long) pos
{
	pointer = pos;
}

- (unsigned long long) length
{
	return  [data length];
}

- (void) testReadInt
{
	char buffer[17] = {0x80, 0x01, (char)0xFF, 0x7F,
		(char)0x80, (char)0x80, 0x01,
		(char)0x81, (char)0x80, 0x01,
		0x06, 'L', 'u', 'c', 'e', 'n', 'e'};
	NSData *d = [[NSData alloc] initWithBytes: buffer length: 17];
	LCIndexInput *is = [[TestMockIndexInput alloc] initWithData: d];
	UKIntsEqual(0x8001FF7F, [is readInt]);
}

- (void) testReadVInt
{
	char buffer[17] = {(char)0x80, 0x01, (char)0xFF, 0x7F,
		(char)0x80, (char)0x80, 0x01,
		(char)0x81, (char)0x80, 0x01,
		0x06, 'L', 'u', 'c', 'e', 'n', 'e'};
	NSData *d = [[NSData alloc] initWithBytes: buffer length: 17];
	LCIndexInput *is = [[TestMockIndexInput alloc] initWithData: d];
	UKIntsEqual(128, [is readVInt]);
	UKIntsEqual(16383, [is readVInt]);
	UKIntsEqual(16384, [is readVInt]);
	UKIntsEqual(16385, [is readVInt]);
	UKStringsEqual(@"Lucene", [is readString]);
}

@end
