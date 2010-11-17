#ifndef __LUCENE_SEARCH_SEARCHABLE__
#define __LUCENE_SEARCH_SEARCHABLE__

#include <Foundation/Foundation.h>
#include "LCWeight.h"

@class LCQuery;
@class LCFilter;
@class LCHitCollector;
@class LCTerm;
@class LCDocument;
@class LCExplanation;
@class LCTopDocs;
@class LCTopFieldDocs;
@class LCSort;

@protocol LCSearchable <NSObject>
- (void) close;
- (int) documentFrequencyWithTerm: (LCTerm *) term;
- (NSArray *) documentFrequencyWithTerms: (NSArray *) terms;
- (int) maximalDocument;
/* if closed, -document: will not work propertly */
- (LCDocument *) document: (int) i;
- (LCQuery *) rewrite: (LCQuery *) query;
- (void) search: (id <LCWeight>) weight 
		 filter: (LCFilter *) filter
   hitCollector: (LCHitCollector *) results;
- (LCTopDocs *) search: (id <LCWeight>) weight 
                filter: (LCFilter *) filter
			   maximum: (int) n;
- (LCTopFieldDocs *) search: (id <LCWeight>) weight 
                     filter: (LCFilter *) filter
					maximum: (int) n
					   sort: (LCSort *) sort;
- (LCExplanation *) explain: (id <LCWeight>) weight 
				   document: (int) doc;
@end
#endif /* __LUCENE_SEARCH_SEARCHABLE__ */
