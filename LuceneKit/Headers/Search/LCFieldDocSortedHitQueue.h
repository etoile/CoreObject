#ifndef __LUCENE_SEARCH_FIELD_DOC_SORTED_HIT_QUEUE__
#define __LUCENE_SEARCH_FIELD_DOC_SORTED_HIT_QUEUE__

#include "LCPriorityQueue.h"

@interface LCFieldDocSortedHitQueue: LCPriorityQueue
{
	NSArray *fields;
	NSArray *collator;
}

- (id) initWithField: (NSArray *) fields size: (int) size;
- (void) setFields: (NSArray *) fields;
- (NSArray *) fields;
- (NSArray *) hasCollators: (NSArray *) fields;

@end

#endif /* __LUCENE_SEARCH_FIELD_DOC_SORTED_HIT_QUEUE__ */
