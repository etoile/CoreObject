#include "LCTermVectorOffsetInfo.h"

@implementation LCTermVectorOffsetInfo

- (id) initWithStartOffset: (int) so endOffset: (int) eo
{
	self = [self init];
	startOffset = so;
	endOffset = eo;
	return self;
}

- (int) endOffset
{
	return endOffset;
}

- (void) setEndOffset: (int) eo
{
	endOffset = eo;
}

- (int) startOffset
{
	return startOffset;
}

- (void) setStartOffset: (int) so
{
	startOffset = so;
}

- (BOOL) isEqual: (id) o
{
	if (self == o) return YES;
	if ([o isKindOfClass: [LCTermVectorOffsetInfo class]] == NO) return NO;
	
	LCTermVectorOffsetInfo *info= (LCTermVectorOffsetInfo *) o;
	
	if (endOffset != [info endOffset]) return NO;
	if (startOffset != [info startOffset]) return NO;
	
	return YES;
}

- (NSUInteger) hash
{
	unsigned result;
	result = startOffset;
	result = 29 * result + endOffset;
	return result;
}

@end
