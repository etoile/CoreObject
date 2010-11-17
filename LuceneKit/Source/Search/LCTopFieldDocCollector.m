#include "LCTopFieldDocCollector.h"
#include "LCIndexReader.h"
#include "LCSort.h"
#include "LCFieldSortedHitQueue.h"
#include "LCTopFieldDocs.h"
#include "GNUstep.h"

/** A {@link HitCollector} implementation that collects the top-sorting
 * documents, returning them as a {@link TopFieldDocs}.  This is used by {@link
 * IndexSearcher} to implement {@link TopFieldDocs}-based search.
 *
 * <p>This may be extended, overriding the collect method to, e.g.,
 * conditionally invoke <code>super()</code> in order to filter which
 * documents are collected.
 **/
@implementation LCTopFieldDocCollector

  /** Construct to collect a given number of hits.
   * @param reader the index to be searched
   * @param sort the sort criteria
   * @param numHits the maximum number of hits to collect
   */
- (id) initWithReader: (LCIndexReader *) reader 
       sort: (LCSort *) sort
       maximalHits: (int) nh
{
	LCFieldSortedHitQueue *fshq = [[LCFieldSortedHitQueue alloc] initWithReader: reader sortFields: [sort sortFields] size: nh];
	return [super initWithMaximalHits: nh queue: AUTORELEASE(fshq)];
}

  // inherited
- (void) collect: (int) doc score: (float) score
{
	if (score > 0.0f)
	{
		totalHits++;
		LCFieldDoc *d = [[LCFieldDoc alloc] initWithDocument: doc score: score];
		[hq insert: d];
		DESTROY(d);
	}
}

  // inherited
- (LCTopDocs *) topDocs
{
	LCFieldSortedHitQueue *fshq = (LCFieldSortedHitQueue *) hq;
	NSMutableArray *scoreDocs = AUTORELEASE([[NSMutableArray alloc] init]);
	int i, count = [fshq size]-1;
	for (i = count; i >= 0; i--) // put docs in array
	{
		[scoreDocs insertObject: [fshq fillFields: (LCFieldDoc *)[fshq pop]] atIndex: 0];
	}
	LCTopFieldDocs *d = [[LCTopFieldDocs alloc] initWithTotalHits: totalHits 
                  scoreDocuments: scoreDocs
                          sortFields: [fshq sortFields]
                        maxScore: [fshq maximalScore]];
	return AUTORELEASE(d);
}

@end
