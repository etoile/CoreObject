#ifndef __LUCENE_SEARCH_TOP_FIELD_DOCS__
#define __LUCENE_SEARCH_TOP_FIELD_DOCS__

#include "LCTopDocs.h"

@interface LCTopFieldDocs: LCTopDocs
{
	NSArray *fields;
}
- (id) initWithTotalHits: (int) totalHits 
		  scoreDocuments: (NSArray *) scoreDocs
			  sortFields: (NSArray *) fields
			maxScore: (float) maxScore;
@end

#endif /* __LUCENE_SEARCH_TOP_FIELD_DOCS__ */
