#ifndef __LUCENE_SEARCH_BOOLEAN_CLAUSE__
#define __LUCENE_SEARCH_BOOLEAN_CLAUSE__

#include <Foundation/Foundation.h>

typedef enum _OCCUR_TYPE
{
	LCOccur_MUST = 1,
	LCOccur_SHOULD,
	LCOccur_MUST_NOT
} LCOccurType;

@class LCQuery;

@interface LCBooleanClause: NSObject // Serializable
{
	LCOccurType occur;
	LCQuery *query; // remove for lucene 2.0
}

- (id) initWithQuery: (LCQuery *) q
			   occur: (LCOccurType) o;
- (LCOccurType) occur;
- (void) setOccur: (LCOccurType) o;
- (NSString *) occurString;
- (LCQuery *) query;
- (void) setQuery: (LCQuery *) q;

- (BOOL) isProhibited;
- (BOOL) isRequired;

@end
#endif /* __LUCENE_SEARCH_BOOLEAN_CLAUSE__ */
