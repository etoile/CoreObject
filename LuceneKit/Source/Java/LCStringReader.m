#include "LCStringReader.h"
#include "GNUstep.h"

@implementation LCStringReader
- (id) initWithString: (NSString *) s
{
	self = [self init];
	ASSIGNCOPY(source, s);
	return self;
}

- (void) dealloc
{
	DESTROY(source);
	[super dealloc];
}

- (void) close
{
	// Do something 
}

- (int) read
{
	if (pos >= [source length]) return -1;
	return (int)[source characterAtIndex: pos++];
}
- (int) read: (unichar *) buf length: (unsigned int) len
{
	if (pos >= [source length]) return -1;
	if ((pos+len) > [source length])
		len = [source length]-pos;
	NSRange range = NSMakeRange(pos, len);
	[source getCharacters: buf range: range];
	pos += len;
	return len;
}

- (BOOL) ready
{
	return YES;
}

- (long) skip: (long) n
{
	if ((pos+n) > [source length])
    {
		pos = [source length];
		return ([source length]-pos);
    }
	else
    {
		pos += n;
		return n;
    }
}

@end
