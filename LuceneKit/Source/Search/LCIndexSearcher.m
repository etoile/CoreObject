#include "LCIndexSearcher.h"
#include "LCFieldSortedHitQueue.h"
#include "LCHitQueue.h"
#include "LCFilter.h"
#include "LCScoreDoc.h"
#include "LCTopFieldDocs.h"
#include "LCQuery.h"
#include "LCSort.h"
#include "LCBitVector.h"
#include "LCIndexReader.h"
#include "LCTerm.h"
#include "LCDocument.h"
#include "LCTopDocCollector.h"
#include "LCTopFieldDocCollector.h"
#include "GNUstep.h"
#include "float.h"

/** Implements search over a single IndexReader.
*
* <p>Applications usually need only call the inherited {@link #search(Query)}
* or {@link #search(Query,Filter)} methods. For performance reasons it is 
* recommended to open only one IndexSearcher and use it for all of your searches.
*/
@interface LCHitCollector3: LCHitCollector
{
	LCBitVector *bits;
	LCHitCollector *collector;
}
- (id) initWithReader: (LCIndexReader *) reader
			   filter: (LCFilter *) filter
		 hitCollector: (LCHitCollector *) collector;
@end

@implementation LCHitCollector3

- (id) initWithReader: (LCIndexReader *) reader
			   filter: (LCFilter *) filter
		 hitCollector: (LCHitCollector *) hc 
{
	self = [self init];
	bits = [filter bits: reader];
	ASSIGN(collector, hc);
	return self;
}

- (void) collect: (int) doc score: (float) score
{
	if ([bits bit: doc]) // skip docs not in bits
	{
		[collector collect: doc score: score];
	}
}

- (void) dealloc
{
	DESTROY(collector);
	[super dealloc];
}
@end

@interface LCIndexSearcher (LCPrivate)
- (id) initWithReader: (LCIndexReader *) indexReader close: (BOOL) closeReader;
@end

@implementation LCIndexSearcher

/** Creates a searcher searching the index in the named directory. */
- (id) initWithPath: (NSString *) path
{
	return [self initWithReader: [LCIndexReader openPath: path] close: YES];
}

/** Creates a searcher searching the index in the provided directory. */
- (id) initWithDirectory: (id <LCDirectory>) directory
{
	return [self initWithReader: [LCIndexReader openDirectory: directory] 
						  close: YES];
}

/** Creates a searcher searching the provided index. */
- (id) initWithReader: (LCIndexReader *) indexReader
{
	return [self initWithReader: indexReader close: NO];
}

- (id) initWithReader: (LCIndexReader *) indexReader close: (BOOL) close
{
	self = [self init];
	ASSIGN(reader, indexReader);
	closeReader = close;
	return self;
}

- (void) dealloc
{
  DESTROY(reader);
  [super dealloc];
}

/** Return the {@link IndexReader} this searches. */
- (LCIndexReader *) indexReader
{
	return reader;
}

/**
* Note that the underlying IndexReader is not closed, if
 * IndexSearcher was constructed with IndexSearcher(IndexReader r).
 * If the IndexReader was supplied implicitly by specifying a directory, then
 * the IndexReader gets closed.
 */
- (void) close
{
	if(closeReader)
		[reader close];
}

- (int) documentFrequencyWithTerm: (LCTerm *) term
{
	return [reader documentFrequency: term];
}

- (LCDocument *) document: (int) i
{
	return [reader document: i];
}

- (int) maximalDocument
{
	return [reader maximalDocument];
}

- (LCTopDocs *) search: (id <LCWeight>) weight
                filter: (LCFilter *) filter
			   maximum: (int) nDocs
{
	if (nDocs <= 0)  // null might be returned from hq.top() below.
	{
		NSLog(@"nDocs must be > 0 ");
		return nil;
	}
	
	LCTopDocCollector *collector = [[LCTopDocCollector alloc] initWithMaximalHits: nDocs];
	[self search: weight filter: filter hitCollector: collector];
	AUTORELEASE(collector);
	return [collector topDocs];
}

- (LCTopFieldDocs *) search: (id <LCWeight>) weight 
                     filter: (LCFilter *) filter
					maximum: (int) nDocs
					   sort: (LCSort *) sort
{
	LCTopFieldDocCollector *collector = [[LCTopFieldDocCollector alloc] initWithReader: reader sort: sort maximalHits: nDocs];
	[self search: weight filter: filter hitCollector: collector];
	AUTORELEASE(collector);
	return (LCTopFieldDocs *)[collector topDocs];
}

- (void) search: (id <LCWeight>) weight 
         filter: (LCFilter *) filter
   hitCollector: (LCHitCollector *) results
{
	LCHitCollector *collector = results;
	if (filter != nil) {
		collector = [[LCHitCollector3 alloc] initWithReader: reader 
													 filter: filter hitCollector: results];
		AUTORELEASE(collector);
	}
	LCScorer *scorer = [weight scorer: reader];
	if (scorer == nil) return;
	[scorer score: collector];
}

- (LCQuery *) rewrite: (LCQuery *) original
{
	LCQuery *query = original;
	LCQuery *rewrittenQuery;
	for (rewrittenQuery = [query rewrite: reader]; rewrittenQuery != query;
         rewrittenQuery = [query rewrite: reader]) {
		query = rewrittenQuery;
	}
	return query;
}

- (LCExplanation *) explain: (id <LCWeight>) weight 
				   document: (int) doc
{
	return [weight explain: reader document: doc];
}

@end
