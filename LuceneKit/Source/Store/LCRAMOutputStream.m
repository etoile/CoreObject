#include "LCRAMOutputStream.h"
#include "GNUstep.h"

/**
* A memory-resident {@link IndexOutput} implementation.
 *
 * @version $Id$
 */

@implementation LCRAMOutputStream

/** Construct an empty output buffer. */
- (id) init
{
	self = [super init];
	ASSIGN(file, AUTORELEASE([[LCRAMFile alloc] init]));
	pointer = 0;
	return self;
}

- (void) dealloc
{
	DESTROY(file);
	[super dealloc];
}

- (id) initWithFile: (LCRAMFile *) f
{
	self = [self init];
	ASSIGN(file, f);
	return self;
}

- (void) writeByte: (char) b
{
	NSData *d = [NSData dataWithBytes: &b length: 1];
	[self writeBytes: d length: 1];
}

- (void) writeBytes: (NSData *) b length: (int) len
{
	NSRange r;
	if (file)
	{
		if (pointer == [file length]) /* The end of file */
		{
			r = NSMakeRange(0, len);
			[file addData: [b subdataWithRange: r]];
		}
		else if (pointer < [file length]) /* within file */
		{
			r = NSMakeRange(0, pointer);
			NSData *new1 = [[file buffers] subdataWithRange: r];
			NSData *new2 = nil;
			if (pointer+len < [file length])
			{
				r = NSMakeRange(pointer+len, [file length]-pointer-len);
				new2 = [[file buffers] subdataWithRange: r];
			}
			
			[file setLength: 0];
			[file addData: new1];
			r = NSMakeRange(0, len);
			[file addData: [b subdataWithRange: r]];
			if (new2) [file addData: new2];
		}
		
		pointer += len;
	}
}

- (void) flush
{
}

- (void) close
{
}

- (void) seekToFileOffset: (unsigned long long) pos
{
	pointer = pos;
}

- (unsigned long long) offsetInFile
{
	return pointer;
}

- (unsigned long long) length
{
	return [file length];
}

- (void) writeTo: (LCIndexOutput *) o
{
	[o writeBytes: [file buffers] length: [file length]];
}

- (void) reset
{
	[self seekToFileOffset: 0];
	[file setLength: 0];
}


@end
