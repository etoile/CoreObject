#include "LCScorer.h"
#include "GNUstep.h"

/** Expert: Common scoring functionality for different types of queries.
* <br>A <code>Scorer</code> either iterates over documents matching a query,
* or provides an explanation of the score for a query for a given document.
* <br>Document scores are computed using a given <code>Similarity</code> implementation.
*/
@implementation LCScorer
/** Constructs a Scorer.
* @param similarity The <code>Similarity</code> implementation used by this scorer.
*/
- (id) initWithSimilarity: (LCSimilarity *) si
{
	self = [self init];
	ASSIGN(similarity, si);
	return self;
}

- (void) dealloc
{
	DESTROY(similarity);
	[super dealloc];
}

/** Returns the Similarity implementation used by this scorer. */
- (LCSimilarity *) similarity
{
	return similarity;
}

/** Scores and collects all matching documents.
* @param hc The collector to which all matching documents are passed through
* {@link HitCollector#collect(int, float)}.
* <br>When this method is used the {@link #explain(int)} method should not be used.
*/
- (void) score: (LCHitCollector *) hc
{
	while ([self next]) {
		[hc collect: [self document] score: [self score]];
	}
}

/** Expert: Collects matching documents in a range.  Hook for optimization.
* Note that {@link #next()} must be called once before this method is called
* for the first time.
* @param hc The collector to which all matching documents are passed through
* {@link HitCollector#collect(int, float)}.
* @param max Do not score documents past this.
* @return true if more matching documents may remain.
*/
- (BOOL) score: (LCHitCollector *) hc
         maximalDocument: (int) max
{
	while ([self document] < max) {
		[hc collect: [self document] score: [self score]];
		if (![self next])
			return NO;
    }
    return YES;
}

/** Advances to the next document matching the query.
* @return true iff there is another document matching the query.
* <br>When this method is used the {@link #explain(int)} method should not be used.
*/
- (BOOL) next { return NO; }

	/** Returns the current document number matching the query.
	* Initially invalid, until {@link #next()} is called the first time.
	*/
- (int) document { return -1; }

	/** Returns the score of the current document matching the query.
	* Initially invalid, until {@link #next()} or {@link #skipTo(int)}
	* is called the first time.
	*/
- (float) score { return -1; }

	/** Skips to the first match beyond the current whose document number is
	* greater than or equal to a given target.
	* <br>When this method is used the {@link #explain(int)} method should not be used.
	* @param target The target document number.
	* @return true iff there is such a match.
	* <p>Behaves as if written: <pre>
	*   boolean skipTo(int target) {
		*     do {
			*       if (!next())
				* 	     return false;
			*     } while (target > doc());
		*     return true;
		*   }
	* </pre>Most implementations are considerably more efficient than that.
	*/
- (BOOL) skipTo: (int) target { return NO; }

	/** Returns an explanation of the score for a document.
	* <br>When this method is used, the {@link #next()}, {@link #skipTo(int)} and
	* {@link #score(HitCollector)} methods should not be used.
	* @param doc The document number for the explanation.
	*/
- (LCExplanation *) explain: (int) doc { return nil; }

@end
