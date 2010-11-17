#include "LCFSIndexInput.h"
#include "GNUstep.h"

@interface LCFSIndexInput (LCPrivate)
- (void) setClosed: (BOOL) isClosed;
@end

@implementation LCFSIndexInput

- (id) copyWithZone: (NSZone *) zone;
{
	LCFSIndexInput *clone = [[LCFSIndexInput allocWithZone: zone] initWithFile: path];
	[clone seekToFileOffset: [self offsetInFile]];
	[clone setClosed: isClosed];
	return clone;
}

- (id) init
{
  self = [super init];
  isClosed = YES;
  return self;
}

- (id) initWithFile: (NSString *) absolutePath
{
	self = [self init];
	ASSIGNCOPY(path, absolutePath);
	ASSIGN(handle, [NSFileHandle fileHandleForReadingAtPath: path]);
	isClosed = NO;
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDictionary *d = [manager fileAttributesAtPath: path
					   traverseLink: YES];
	length = [[d objectForKey: NSFileSize] longValue];
	return self;
}

- (char) readByte
{
	char b;
	NSData *d = [handle readDataOfLength: 1];
	[d getBytes: &b length: 1];
	return b;
}

- (void) readBytes: (NSMutableData *) b 
			offset: (int) offset length: (int) len
{
	if (isClosed)
	{
		NSLog(@"Error: %@ is closed", path);
		return;
	}
	NSData *d = [handle readDataOfLength: len];
	unsigned l = [d length];
	NSRange r = NSMakeRange(offset, l);
	char *buf = malloc(sizeof(char)*l);
	[d getBytes: buf length: l];
	[b replaceBytesInRange: r withBytes: buf];
	free(buf);
	buf = NULL;
}

- (unsigned long long) offsetInFile
{
	return [handle offsetInFile];
}

- (void) seekToFileOffset: (unsigned long long) pos
{
	if (isClosed)
	{
		NSLog(@"Error: %@ is closed", self);
		return;
	}

	if (pos < [self length])
        {
		[handle seekToFileOffset: pos];
        }
	else
        {
		[handle seekToEndOfFile];
        }
}

/** IndexInput methods */
- (void) close
{
	if (isClosed == NO)
	{
		[handle closeFile];
		isClosed = YES;
	}
}

- (unsigned long long) length
{
	if (isClosed)
	{
		NSLog(@"Error: %@ is closed", self);
		return 0;
	}
	return length;
}

- (void) dealloc
{
	[self close];
	DESTROY(handle);
	DESTROY(path);
	[super dealloc];
}

- (void) setClosed: (BOOL) c
{
	isClosed = c;
}

@end
