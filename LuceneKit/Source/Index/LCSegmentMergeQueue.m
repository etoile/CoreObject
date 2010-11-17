#include "LCSegmentMergeQueue.h"
#include "LCSegmentMergeInfo.h"
#include "LCTerm.h"

@implementation LCSegmentMergeQueue

#if 0
- (BOOL) lessThan: (id) a : (id) b
{
	LCSegmentMergeInfo *stiA = (LCSegmentMergeInfo *)a;
	LCSegmentMergeInfo *stiB = (LCSegmentMergeInfo *)b;
	NSComparisonResult comparison = [[stiA term] compare: [stiB term]];
    if (comparison == NSOrderedSame)
		return ([stiA base] < [stiB base]); 
    else
		return (comparison == NSOrderedAscending) ? YES : NO;
}
#endif

- (void) close
{
    while ([self top] != nil)
		[((LCSegmentMergeInfo *)[self pop]) close];
}

@end
