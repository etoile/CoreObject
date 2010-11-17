#ifndef __LUCENE_SEARCH_QUERY__
#define __LUCENE_SEARCH_QUERY__

#include <Foundation/Foundation.h>
#include "LCWeight.h"
#include "LCSearcher.h"
#include "LCSimilarity.h"
#include "LCIndexReader.h"

@interface LCQuery: NSObject <NSCopying> // Seriable
{
	float boost;
}
- (void) setBoost: (float) b;
- (float) boost;
- (NSString *) descriptionWithField: (NSString *) field;
- (id <LCWeight>) weight: (LCSearcher *) searcher;
- (LCQuery *) rewrite: (LCIndexReader *) reader;
- (LCQuery *) combine: (NSArray *) queries;
- (void) extractTerms: (NSMutableArray *) terms;
+ (LCQuery *) mergeBooleanQueries: (NSArray *) queries;
- (LCSimilarity *) similarity: (LCSearcher *) searcher;
@end

@interface LCQuery (LCProtected)
- (id <LCWeight>) createWeight: (LCSearcher *) searcher;
@end
#endif /* __LUCENE_SEARCH_QUERY__ */
