#ifndef __LUCENE_SEARCH_SORT_COMPARATOR_SOURCE__
#define __LUCENE_SEARCH_SORT_COMPARATOR_SOURCE__

#include <Foundation/Foundation.h>

@class LCIndexReader;

@protocol LCSortComparatorSource <NSObject>
/* should return (id <LCScoreDoccomparator>) */
- (id) newComparator: (LCIndexReader *) reader
			   field: (NSString *) fieldname;
@end

#endif /* __LUCENE_SEARCH_SORT_COMPARATOR_SOURCE__ */
