#include "LCSegmentMergeInfo.h"
#include "GNUstep.h"

@implementation LCSegmentMergeInfo
- (id) initWithBase: (int) b termEnumerator: (LCTermEnumerator *) te
			 reader: (LCIndexReader *) r
{
	self = [super init];
	base = b;
	ASSIGN(reader, r);
	ASSIGN(termEnum, te);
	ASSIGN(term, [te term]);
	postings = nil;
	docMap = nil;
	return self;
}

- (void) dealloc
{
	DESTROY(reader);
	DESTROY(termEnum);
	DESTROY(term);
	DESTROY(postings);
	DESTROY(docMap);
	[super dealloc];
}
	
- (NSArray *) docMap
{
    if (docMap == nil)
    {
    // build array which maps document numbers around deletions 
	if ([reader hasDeletions]) {
		int maxDoc = [reader maximalDocument];
		ASSIGN(docMap, AUTORELEASE([[NSMutableArray alloc] init]));
		int j = 0;
		int i;
		for (i = 0; i < maxDoc; i++) {
			if ([reader isDeleted: i])
				[docMap addObject: [NSNumber numberWithInt: -1]];
			else
				[docMap addObject: [NSNumber numberWithInt: j++]];
		}
    }
    }
	return docMap;
}

- (id <LCTermPositions>) postings
{
	if (postings == nil) {
		ASSIGN(postings, [reader termPositions]);
	}
	return postings;
}

- (BOOL) hasNextTerm
{
    if ([termEnum hasNextTerm]) {
		ASSIGN(term, [termEnum term]);
		return YES;
    } else {
		DESTROY(term);
		return NO;
    }
}

- (void) close
{
    [termEnum close];
    if (postings != nil) {
	    [postings close];
	}
}

- (LCTerm *) term { return term; }
- (LCTermEnumerator *) termEnumerator { return termEnum; }
- (int) base { return base; }
- (NSString *) description
{ 
	return [NSString stringWithFormat: @"LCSegmentMergeInfo %@, base %d", term, base];
}

- (NSComparisonResult) compare: (id) o
{
	LCSegmentMergeInfo *other = (LCSegmentMergeInfo *) o;
	NSComparisonResult comparison = [[self term] compare: [other term]];
	if (comparison == NSOrderedSame)
    {
		if ([self base] < [other base])
			return NSOrderedAscending;
		else if ([self base] > [other base])
			return NSOrderedDescending;
		else
			return NSOrderedSame;
    }
	else
		return comparison;
}

@end
