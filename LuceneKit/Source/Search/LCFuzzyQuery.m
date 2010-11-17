#include "LCFuzzyQuery.h"
#include "LCTermQuery.h"
#include "LCBooleanQuery.h"
#include "LCFuzzyTermEnum.h"
#include "LCSmallFloat.h"
#include "NSString+Additions.h"
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

/** Implements the fuzzy search query. The similiarity measurement
 * is based on the Levenshtein (edit distance) algorithm.
 */
@implementation LCFuzzyQuery
  
  /**
   * Create a new FuzzyQuery that will match terms with a similarity 
   * of at least <code>minimumSimilarity</code> to <code>term</code>.
   * If a <code>prefixLength</code> &gt; 0 is specified, a common prefix
   * of that length is also required.
   * 
   * @param term the term to search for
   * @param minimumSimilarity a value between 0 and 1 to set the required similarity
   *  between the query term and the matching terms. For example, for a
   *  <code>minimumSimilarity</code> of <code>0.5</code> a term of the same length
   *  as the query term is considered similar to the query term if the edit distance
   *  between both terms is less than <code>length(term)*0.5</code>
   * @param prefixLength length of common (non-fuzzy) prefix
   * @throws IllegalArgumentException if minimumSimilarity is &gt;= 1 or &lt; 0
   * or if prefixLength &lt; 0
   */
- (id) initWithTerm: (LCTerm *) t
  minimumSimilarity: (float) ms
       prefixLength: (int) pl
{
	self = [super initWithTerm: t];
	if (minimumSimilarity >= 1.0f) 
	{
		NSLog(@"minimumSimilarity >= 1");
		return nil;
	}
	else if (minimumSimilarity < 0) 
	{
		NSLog(@"minimumSimilarity < 0");
		return nil;
	}
	if (pl < 0)
	{
		NSLog(@"prefixLength < 0");
		return nil;
	}
	
	minimumSimilarity = ms;
	prefixLength = pl;
	return self;
}
	
- (id) initWithTerm: (LCTerm *) t
  minimumSimilarity: (float) ms
{
	return [self initWithTerm: t minimumSimilarity: ms prefixLength: defaultPrefixLength];
}

- (id) initWithTerm: (LCTerm *) t
{
	return [self initWithTerm: t minimumSimilarity: defaultMinSimilarity prefixLength: defaultPrefixLength];
}
  
  /**
   * Returns the minimum similarity that is required for this query to match.
   * @return float value between 0.0 and 1.0
   */
- (float) minSimilarity { return minimumSimilarity; }
	/**
	* Returns the non-fuzzy prefix length. This is the number of characters at the start
	 * of a term that must be identical (not fuzzy) to the query term if the query
	 * is to match that term. 
	 */

- (int) prefixLength { return prefixLength; }

+ (float) defaultMinSimilarity { return defaultMinSimilarity; }
+ (int) defaultPrefixLength { return defaultPrefixLength; }



- (LCFilteredTermEnumerator *) enumerator: (LCIndexReader *) reader
{
	return AUTORELEASE([[LCFuzzyTermEnumerator alloc] initWithReader: reader term: [self term] similarity: minimumSimilarity prefixLength: prefixLength]);
}

- (LCQuery *) rewrite: (LCIndexReader *) reader
{
	LCBooleanQuery *query = [[LCBooleanQuery alloc] initWithCoordination: YES];
	CREATE_AUTORELEASE_POOL(pool);
	LCFilteredTermEnumerator *enumerator = [self enumerator: reader];
	int maxClauseCount = [LCBooleanQuery maxClauseCount];
	LCScoreTermQueue *stQueue = [(LCScoreTermQueue *)[LCScoreTermQueue alloc] initWithSize: maxClauseCount];
	
	do {
		float minScore = 0.0f;
		float score = 0.0f;
		LCTerm *t = [enumerator term];
		if (t != nil) {
			score = [enumerator difference];
			// terms come in alphabetical order, therefore if queue is full and score
			// not bigger than minScore, we can skip
			if (([stQueue size] < maxClauseCount) || (score > minScore)) {
				LCScoreTerm *sterm = [[LCScoreTerm alloc] initWithTerm: t score: score];
				[stQueue insert: sterm];
				minScore = [(LCScoreTerm *)[stQueue top] score]; // maintain minScore
				DESTROY(sterm);
			}
		}
	} while ([enumerator hasNextTerm]);
	[enumerator close];
	
	int i, size = [stQueue size];
	for (i = 0; i < size; i++) {
		LCScoreTerm *st = (LCScoreTerm *) [stQueue pop];
		LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: [st term]]; // found a match
		[tq setBoost: [self boost] * [st score]]; // set the boost
		[query addQuery: tq occur: LCOccur_SHOULD]; // add to query
		DESTROY(tq);
	}
        DESTROY(stQueue);
	DESTROY(pool);
	return AUTORELEASE(query);
}

    
- (NSString *) descriptionWithField: (NSString *) field
{
	NSMutableString *ms = [[NSMutableString alloc] init];
	LCTerm *t = [self term];
	if (![[t field] isEqual: field]) {
		[ms appendFormat: @"%@:", [t field]];
	}
	[ms appendFormat: @"%@~%f%@", [t text], minimumSimilarity, LCStringFromBoost([self boost])];
	return AUTORELEASE(ms);
}

- (BOOL) isEqual: (id) o
{
	if (self == o) return YES;
	if (![o isKindOfClass: [LCFuzzyQuery class]]) return NO;
	//		if (!super.equals(o)) return false;  // LuceneKit: weird.
	LCFuzzyQuery *fuzzyQuery = (LCFuzzyQuery *) o;
	if (minimumSimilarity != [fuzzyQuery minSimilarity]) return NO;
	if (prefixLength != [fuzzyQuery prefixLength]) return NO;
	return YES;
}

- (NSUInteger) hash
{
	int result = [super hash];
	//		result = 29 * result + minimumSimilarity != +0.0f ? Float.floatToIntBits(minimumSimilarity) : 0;
	result = (29 * result + minimumSimilarity != +0.0f) ? (int)(FloatToIntBits(minimumSimilarity)) : 0;
	result = 29 * result + prefixLength;
	return result;
}

@end

@implementation LCScoreTerm

- (id) initWithTerm: (LCTerm *) t score: (float) s
{
	self = [self init];
	ASSIGN(term, t);
	score = s;
	return self;
}

- (void) dealloc
{
	DESTROY(term);
	[super dealloc];
}

- (float) score { return score; }
- (LCTerm *) term { return term; }
- (NSComparisonResult) compare: (id) other
{
	LCScoreTerm *termB = (LCScoreTerm *) other;
	if ([self score] == [termB score])
		return [[self term] compare: [termB term]];
	else if ([self score] < [termB score])
		return NSOrderedAscending;
	else
		return NSOrderedDescending;
}

@end
  
@implementation LCScoreTermQueue
// Put comparasion to LCScoreTerm
@end
