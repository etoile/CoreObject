#include "LCSearcher.h"
#include "LCSimilarity.h"
#include "LCHits.h"
#include "LCQuery.h"
#include "LCSort.h"
#include "LCFilter.h"
#include "LCHitCollector.h"
#include "GNUstep.h"
#include "LCWeight.h"

/** An abstract base class for search implementations.
* Implements some common utility methods.
*/
@implementation LCSearcher

- (id) init
{
	self = [super init];
	ASSIGN(similarity, [LCSimilarity defaultSimilarity]);
	return self;
}

- (void) dealloc
{
	DESTROY(similarity);
	[super dealloc];
}

- (LCHits *) search: (LCQuery *) query
{
	return [self search: query filter: nil];
}

- (LCHits *) search: (LCQuery *) query
			 filter: (LCFilter *) filter
{
	return AUTORELEASE([[LCHits alloc] initWithSearcher: self query: query filter: filter]);
}

- (LCHits *) search: (LCQuery *) query sort: (LCSort *) sort
{
	return AUTORELEASE([[LCHits alloc] initWithSearcher: self query: query filter: nil sort: sort]);
}

- (LCHits *) search: (LCQuery *) query 
             filter: (LCFilter *) filter sort: (LCSort *) sort
{
	return AUTORELEASE([[LCHits alloc] initWithSearcher: self query: query filter: filter sort: sort]);
}

/** Expert: Low-level search implementation with arbitrary sorting.  Finds
* the top <code>n</code> hits for <code>query</code>, applying
* <code>filter</code> if non-null, and sorting the hits by the criteria in
* <code>sort</code>.
*
* <p>Applications should usually call {@link
	* Searcher#search(Query,Filter,Sort)} instead.
* @throws BooleanQuery.TooManyClauses
*/
- (LCTopFieldDocs *) searchQuery: (LCQuery *) query filter: (LCFilter *) filter maximum: (int) n sort: (LCSort *) sort
{
	return [self search: [self createWeight: query] filter: filter maximum: n sort: sort];
}

/** Lower-level search API.
*
* <p>{@link HitCollector#collect(int,float)} is called for every non-zero
* scoring document.
*
* <p>Applications should only use this if they need <i>all</i> of the
* matching documents.  The high-level search API ({@link
	* Searcher#search(Query)}) is usually more efficient, as it skips
* non-high-scoring hits.
* <p>Note: The <code>score</code> passed to this method is a raw score.
* In other words, the score will not necessarily be a float whose value is
* between 0 and 1.
* @throws BooleanQuery.TooManyClauses
*/
- (void) search: (LCQuery *) query
   hitCollector: (LCHitCollector *) results
{
	[self searchQuery: query filter: nil hitCollector: results];
}

/** Lower-level search API.
*
* <p>{@link HitCollector#collect(int,float)} is called for every non-zero
* scoring document.
* <br>HitCollector-based access to remote indexes is discouraged.
*
* <p>Applications should only use this if they need <i>all</i> of the
* matching documents.  The high-level search API ({@link
	* Searcher#search(Query)}) is usually more efficient, as it skips
* non-high-scoring hits.
*
* @param query to match documents
* @param filter if non-null, a bitset used to eliminate some documents
* @param results to receive hits
* @throws BooleanQuery.TooManyClauses
*/
- (void) searchQuery: (LCQuery *) query filter: (LCFilter *) filter hitCollector: (LCHitCollector *) results
{
	[self search: [self createWeight: query] filter: filter hitCollector: results];
}

/** Expert: Low-level search implementation.  Finds the top <code>n</code>
* hits for <code>query</code>, applying <code>filter</code> if non-null.
*
* <p>Called by {@link Hits}.
*
* <p>Applications should usually call {@link Searcher#search(Query)} or
* {@link Searcher#search(Query,Filter)} instead.
* @throws BooleanQuery.TooManyClauses
*/
- (LCTopDocs *) searchQuery: (LCQuery *) query filter: (LCFilter *) filter maximum: (int) n
{
	return [self search: [self createWeight: query] filter: filter maximum: n];
}


/** Expert: Set the Similarity implementation used by this Searcher.
*
* @see Similarity#setDefault(Similarity)
*/
- (void) setSimilarity: (LCSimilarity *) s
{
	ASSIGN(similarity, s);
}

/** Expert: Return the Similarity implementation used by this Searcher.
*
* <p>This defaults to the current value of {@link Similarity#getDefault()}.
*/
- (LCSimilarity *) similarity
{
	return similarity;
}

/** Returns an Explanation that describes how <code>doc</code> scored against
* <code>query</code>.
*
* <p>This is intended to be used in developing Similarity implementations,
* and, for good performance, should not be displayed with every hit.
* Computing an explanation is as expensive as executing the query over the
* entire index.
*/
- (LCExplanation *) explainQuery: (LCQuery *) query document: (int) doc
{
	return [self explain: [self createWeight: query] document: doc];
}

- (NSArray *) documentFrequencyWithTerms: (NSArray *) terms 
{ 
	NSMutableArray *result = [[NSMutableArray alloc] init];
	int i;
	for (i = 0; i < [terms count]; i++)
	{
		[result addObject: [NSNumber numberWithInt: [self documentFrequencyWithTerm: [terms objectAtIndex: i]]]];
	}
	return AUTORELEASE(result); 
}

- (id <LCWeight>) createWeight: (LCQuery *) query
{
	return [query weight: self];
}

/* LuceneKit: subclass responsibility */
- (void) search: (id <LCWeight>) weight 
         filter: (LCFilter *) filter
   hitCollector: (LCHitCollector *) results {}
- (void) close {}
- (int) documentFrequencyWithTerm: (LCTerm *) term { return -1; }
- (int) maximalDocument { return -1; }
- (LCTopDocs *) search: (id <LCWeight>) weight 
                filter: (LCFilter *) filter
			   maximum: (int) n
{ return nil; }
- (LCDocument *) document: (int) i { return nil; }
- (LCQuery *) rewrite: (LCQuery *) query { return nil; }
- (LCExplanation *) explain: (id <LCWeight>) weight 
				   document: (int) doc
{ return nil; }
- (LCTopFieldDocs *) search: (id <LCWeight>) weight 
					 filter: (LCFilter *) filter
					maximum: (int) n
					   sort: (LCSort *) sort
{  return nil; }
@end
