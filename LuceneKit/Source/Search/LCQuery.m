#include "LCQuery.h"
#include "LCBooleanClause.h"
#include "LCBooleanQuery.h"
#include "GNUstep.h"

@interface LCScoreTerm: NSObject <LCComparable>
{
	LCTerm *term;
	float score;
}

- (id) initWithTerm: (LCTerm *) term score: (float) score;
- (float) score;
- (LCTerm *) term;

@end

@interface LCScoreTermQueue: LCPriorityQueue
@end

/** The abstract base class for queries.
<p>Instantiable subclasses are:
<ul>
<li> {@link TermQuery}
<li> {@link MultiTermQuery}
<li> {@link BooleanQuery}
<li> {@link WildcardQuery}
<li> {@link PhraseQuery}
<li> {@link PrefixQuery}
<li> {@link MultiPhraseQuery}
<li> {@link FuzzyQuery}
<li> {@link RangeQuery}
<li> {@link org.apache.lucene.search.spans.SpanQuery}
</ul>
<p>A parser for queries is contained in:
<ul>
<li>{@link org.apache.lucene.queryParser.QueryParser QueryParser}
</ul>
*/
@implementation LCQuery

- (id) init
{
	self = [super init];
	boost = 1.0f;                     // query boost factor
	return self;
}

/** Sets the boost for this query clause to <code>b</code>.  Documents
* matching this clause will (in addition to the normal weightings) have
* their score multiplied by <code>b</code>.
*/
- (void) setBoost: (float) b { boost = b; }

	/** Gets the boost for this clause.  Documents matching
	* this clause will (in addition to the normal weightings) have their score
	* multiplied by <code>b</code>.   The boost is 1.0 by default.
	*/
- (float) boost { return boost; }

	/** Prints a query to a string, with <code>field</code> as the default field
	* for terms.  <p>The representation used is one that is supposed to be readable
	* by {@link org.apache.lucene.queryParser.QueryParser QueryParser}. However,
	* there are the following limitations:
	* <ul>
	*  <li>If the query was created by the parser, the printed
	*  representation may not be exactly what was parsed. For example,
	*  characters that need to be escaped will be represented without
	*  the required backslash.</li>
	* <li>Some of the more complicated queries (e.g. span queries)
	*  don't have a representation that can be parsed by QueryParser.</li>
	* </ul>
	*/
- (NSString *) descriptionWithField: (NSString *) field { return nil; }

	/** Prints a query to a string. */
- (NSString *) description
{
	return [self descriptionWithField: @""];
}

/** Expert: Constructs an appropriate Weight implementation for this query.
*
* <p>Only implemented by primitive queries, which re-write to themselves.
*/
- (id <LCWeight>) createWeight: (LCSearcher *) searcher
{
	NSLog(@"Unsupported");
	return nil;
}

/** Expert: Constructs an initializes a Weight for a top-level query. */
- (id <LCWeight>) weight: (LCSearcher *) searcher
{
	CREATE_AUTORELEASE_POOL(pool);
	LCQuery *query = [searcher rewrite: self];
	id <LCWeight> weight = [query createWeight: searcher];
	RETAIN(weight);
	float sum = [weight sumOfSquaredWeights];
	float norm = [[self similarity: searcher] queryNorm: sum];
	[weight normalize: norm];
	DESTROY(pool);
	AUTORELEASE(weight);
	return weight;
}

/** Expert: called to re-write queries into primitive queries. */
- (LCQuery *) rewrite: (LCIndexReader *) reader
{
	return self;
}

/** Expert: called when re-writing queries under MultiSearcher.
*
* <p>Only implemented by derived queries, with no
* {@link #createWeight(Searcher)} implementatation.
*/
- (LCQuery *) combine: (NSArray *) queries
{
  NSMutableArray *uniques = [[NSMutableArray alloc] init];
  AUTORELEASE(uniques);
  int i, count = [queries count];
  for (i = 0; i < count; i++) {
    LCQuery *query = [queries objectAtIndex: i];
    NSArray *clauses = nil;
    BOOL splittable = [query isKindOfClass: [LCBooleanQuery class]];
    if (splittable) {
      LCBooleanQuery *bq = (LCBooleanQuery *) query;
      splittable = [bq isCoordinationDisabled];
      clauses = [bq clauses];
      int j;
      for (j = 0; splittable && (j < [clauses count]); j++) {
        splittable = ([[clauses objectAtIndex: i] occur] == LCOccur_SHOULD) ? YES: NO;
      }
    }
    if (splittable) {
      int k;
      for (k = 0; k < [clauses count]; k++) {
        [uniques addObject: [(LCBooleanClause *)[clauses objectAtIndex: k] query]];
      }
    } else {
      [uniques addObject: query];
    }
  }

  if ([uniques count] == 1) {
    return [uniques objectAtIndex: 0];
  }

  NSEnumerator *e = [uniques objectEnumerator];
  LCQuery *q;
  LCBooleanQuery *result = [[LCBooleanQuery alloc] initWithCoordination: YES];
  while ((q = [e nextObject]))
  {
    [result addQuery: q occur: LCOccur_SHOULD];
  }
  return AUTORELEASE(result);
}

- (void) extractTerms: (NSMutableArray *) terms
{
	NSLog(@"Unsupported");
}
/** Expert: merges the clauses of a set of BooleanQuery's into a single
* BooleanQuery.
*
*<p>A utility for use by {@link #combine(Query[])} implementations.
*/
+ (LCQuery *) mergeBooleanQueries: (NSArray *) queries
{
	NSMutableArray *allClauses = [[NSMutableArray alloc] init];
	int i;
	for (i = 0; i < [queries count]; i++) 
	{
		NSArray *clauses = [[queries objectAtIndex: i] clauses];
		int j;
		for (j = 0; j < [clauses count]; j++) {
			[allClauses addObject: [clauses objectAtIndex: j]];
		}
	}
	
	BOOL coordDisabled = ([queries count] == 0) ? NO : [[queries objectAtIndex: 0] isCoordinationDisabled];
	LCBooleanQuery *result = [[LCBooleanQuery alloc] initWithCoordination: coordDisabled];
	NSEnumerator *e = [allClauses objectEnumerator];
	LCBooleanClause *clause;
	while ((clause = [e nextObject]))
	{
		[result addClause: clause];
	}
	DESTROY(allClauses);
	return AUTORELEASE(result);
}

/** Expert: Returns the Similarity implementation to be used for this query.
* Subclasses may override this method to specify their own Similarity
* implementation, perhaps one that delegates through that of the Searcher.
* By default the Searcher's Similarity implementation is returned.*/
- (LCSimilarity *) similarity: (LCSearcher *) searcher
{
	return [searcher similarity];
}

/** Returns a clone of this query. */
- (id) copyWithZone: (NSZone *) zone
{
#if 0
	LCQuery *clone = [[LCQuery allocWithZone: zone] init];
#else
	LCQuery *clone = [[[self class] allocWithZone: zone] init];
#endif
	[clone setBoost: boost];
	return clone;
}

@end
