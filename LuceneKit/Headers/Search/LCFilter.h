#ifndef __LUCENE_SEARCH_FILTER__
#define __LUCENE_SEARCH_FILTER__

#include <Foundation/Foundation.h>
#include "LCBitVector.h"
#include "LCIndexReader.h"

@interface LCFilter: NSObject
/* LuceneKit: use LCBitVector for BitSet in Java */
- (LCBitVector *) bits: (LCIndexReader *) reader;
@end

#endif /* __LUCENE_SEARCH_FILTER__ */
