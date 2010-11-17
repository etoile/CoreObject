#include "LCTermBuffer.h"
#include "GNUstep.h"

@implementation LCTermBuffer

- (void) read: (LCIndexInput *) input
   fieldInfos: (LCFieldInfos *) fieldInfos
{
	int start = [input readVInt];
	int length = [input readVInt];
	//  int totalLength = start + length;
	NSMutableString *txt = [[NSMutableString alloc] init];
	if ([self text])
		[txt setString: text];
	[input readChars: txt start: start length: length];
	[self setField: [fieldInfos fieldName: [input readVInt]]];
	[self setText: txt];
	DESTROY(txt);
}

- (id) copyWithZone: (NSZone *) zone
{ 
	LCTermBuffer *clone = [[LCTermBuffer allocWithZone: zone] initWithField: [self field] text: [self text]];
	return clone;
}


@end
