#ifndef __LUCENE_SEARCH_RANGE_FILTER__
#define __LUCENE_SEARCH_RANGE_FILTER__

#include "LCFilter.h"

@interface LCRangeFilter: LCFilter
{
	NSString *fieldName;
	NSString *lowerTerm;
	NSString *upperTerm;
	BOOL includeLower;
	BOOL includeUpper;
}

- (id) initWithField: (NSString *) fieldName lowerTerm: (NSString *) lowerTerm
		   upperTerm: (NSString *) upperTerm includeLower: (BOOL) includeLower
		includeUpper: (BOOL) includeUpper;
+ (LCRangeFilter *) less: (NSString *) fieldName upperTerm: (NSString *) upperTerm;
+ (LCRangeFilter *) more: (NSString *) fieldName lowerTerm: (NSString *) lowerTerm;
- (LCBitVector *) bits: (LCIndexReader *) reader;

@end

#endif /* __LUCENE_SEARCH_RANGE_FILTER__ */
