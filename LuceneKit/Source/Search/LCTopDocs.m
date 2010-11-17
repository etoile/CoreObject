#include "LCTopDocs.h"
#include "GNUstep.h"

/** Expert: Returned by low-level search implementations.
* @see Searcher#search(Query,Filter,int) */
@implementation LCTopDocs: NSObject // Serializable

- (id) initWithTotalHits: (int) th
		  scoreDocuments: (NSArray *) sd
		maxScore: (float) max
{
	self = [super init];
	totalHits = th;
	ASSIGN(scoreDocs, sd);
	maxScore = max;
	return self;
}

- (void) dealloc
{
	DESTROY(scoreDocs);
	[super dealloc];
}

- (int) totalHits { return totalHits; }
- (NSArray *) scoreDocuments { return scoreDocs; }

- (float) maxScore { return maxScore; }
- (void) setMaxScore: (float) max { maxScore = max; }

@end
