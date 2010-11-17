#include "LCTopDocCollector.h"
#include "LCHitQueue.h"
#include "LCScoreDoc.h"
#include "LCTopDocs.h"
#include "GNUstep.h"
#include <float.h>

/** A {@link HitCollector} implementation that collects the top-scoring
 * documents, returning them as a {@link TopDocs}.  This is used by {@link
 * IndexSearcher} to implement {@link TopDocs}-based search.
 *
 * <p>This may be extended, overriding the collect method to, e.g.,
 * conditionally invoke <code>super()</code> in order to filter which
 * documents are collected.
 **/
@implementation LCTopDocCollector

- (id) init
{
	self = [super init];
	minScore = 0.0f;
	totalHits = 0;
	numHits = 0;
	return self;
}

  /** Construct to collect a given number of hits.
   * @param numHits the maximum number of hits to collect
   */
- (id) initWithMaximalHits: (int) max
{
	LCHitQueue *queue = [[LCHitQueue alloc] initWithSize: max];
	return [self initWithMaximalHits: max queue: AUTORELEASE(queue)];
}

- (id) initWithMaximalHits: (int) max queue: (LCPriorityQueue *) q
{
	self = [self init];
	numHits = max;
	ASSIGN(hq, q);
	return self;
}

- (void) dealloc
{
	DESTROY(hq);
	[super dealloc];
}

  // inherited
- (void) collect: (int) doc score: (float) score
{
	if (score > 0.0f)
	{
		totalHits++;
		if (([hq size] < numHits) || (score >= minScore))
		{
			LCScoreDoc *d = [[LCScoreDoc alloc] initWithDocument: doc score: score];
			[hq insert: d];
			minScore = [(LCScoreDoc *)[hq top] score]; // maintain minScore
			DESTROY(d);
		}
	}
}

  /** The total number of documents that matched this query. */
- (int) totalHits
{
	return totalHits;
}

  /** The top-scoring hits. */
- (LCTopDocs *) topDocs
{
	NSMutableArray *scoreDocs = AUTORELEASE([[NSMutableArray alloc] init]);
	int i, count = [hq size]-1;
	for (i = count; i >= 0; i--) // put docs in array
	{
		[scoreDocs insertObject: [hq pop] atIndex: 0];
	}
	float ms = (totalHits == 0) ? FLT_MIN : [[scoreDocs objectAtIndex: 0] score];
	return AUTORELEASE([[LCTopDocs alloc] initWithTotalHits: totalHits scoreDocuments: scoreDocs maxScore: ms]);
}

@end

