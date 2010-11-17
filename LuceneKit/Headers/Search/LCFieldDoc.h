#ifndef __LUCENE_SEARCH_FIELD_DOC__
#define __LUCENE_SEARCH_FIELD_DOC__

#include "LCScoreDoc.h"

@interface LCFieldDoc: LCScoreDoc
{
	NSArray *fields;
}

- (id) initWithDocument: (int) doc 
				  score: (float) score fields: (NSArray *) fields;
- (NSArray *) fields;
- (void) setFields: (NSArray *) fields;
@end

#endif /* __LUCENE_SEARCH_FIELD_DOC__ */
