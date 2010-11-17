#include "LCFuzzyTermEnum.h"
#include "LCFuzzyQuery.h"
#include "GNUstep.h"

@interface LCFuzzyTermEnumerator (LCPrivate)
- (void) initDistanceArray;
- (float) similarity: (NSString *) target;
- (void) growDistanceArray: (int) m;
- (int) maxDistance: (int) m;
- (void) initializeMaxDistances;
- (int) calculateMaxDistance: (int) m;
@end

/** Subclass of FilteredTermEnum for enumerating all terms that are similiar
 * to the specified filter term.
 *
 * <p>Term enumerations are always ordered by Term.compareTo().  Each term in
 * the enumeration is greater than all that precede it.
 */

/**
* Finds and returns the smallest of three integers 
 */
int minOfThree(int a, int b, int c) 
{
	int t = (a < b) ? a : b;
    return (t < c) ? t : c;
}

int minOfTwo(int a, int b)
{
	return (a < b) ? a : b;
}
	
@implementation LCFuzzyTermEnumerator

- (id) init
{
	self = [super init];
	endEnum = NO;
	searchTerm = nil;
	maxDistances = [[NSMutableArray alloc] init];
	return self;
}

  /**
   * Creates a FuzzyTermEnum with an empty prefix and a minSimilarity of 0.5f.
   * <p>
   * After calling the constructor the enumeration is already pointing to the first 
   * valid term if such a term exists. 
   * 
   * @param reader
   * @param term
   * @throws IOException
   * @see #FuzzyTermEnum(IndexReader, Term, float, int)
   */
- (id) initWithReader: (LCIndexReader *) reader term: (LCTerm *) term
{
	return [self initWithReader: reader term: term similarity: [LCFuzzyQuery defaultMinSimilarity]
				   prefixLength: [LCFuzzyQuery defaultPrefixLength]];
}
    
  /**
   * Creates a FuzzyTermEnum with an empty prefix.
   * <p>
   * After calling the constructor the enumeration is already pointing to the first 
   * valid term if such a term exists. 
   * 
   * @param reader
   * @param term
   * @param minSimilarity
   * @throws IOException
   * @see #FuzzyTermEnum(IndexReader, Term, float, int)
   */
- (id) initWithReader: (LCIndexReader *) reader term: (LCTerm *) term 
		   similarity: (float) minSimilarity
{
	return [self initWithReader: reader term: term similarity: minSimilarity
				   prefixLength: [LCFuzzyQuery defaultPrefixLength]];
}
    
  /**
   * Constructor for enumeration of all terms from specified <code>reader</code> which share a prefix of
   * length <code>prefixLength</code> with <code>term</code> and which have a fuzzy similarity &gt;
   * <code>minSimilarity</code>.
   * <p>
   * After calling the constructor the enumeration is already pointing to the first 
   * valid term if such a term exists. 
   * 
   * @param reader Delivers terms.
   * @param term Pattern term.
   * @param minSimilarity Minimum required similarity for terms from the reader. Default value is 0.5f.
   * @param prefixLength Length of required common prefix. Default value is 0.
   * @throws IOException
   */
- (id) initWithReader: (LCIndexReader *) reader term: (LCTerm *) term 
		   similarity: (float) s prefixLength: (int) prefixLength
{
	self = [self init];
    if (s >= 1.0f)
	{
		NSLog(@"minimumSimilarity cannot be greater than or equal to 1");
		return nil;
	}
    else if (s < 0.0f)
	{
		NSLog(@"minimumSimilarity cannot be less than 0");
		return nil;
	}
    if(prefixLength < 0)
	{
		NSLog(@"prefixLength cannot be less than 0");
		return nil;
	}

    minimumSimilarity = s;
    scale_factor = 1.0f / (1.0f - minimumSimilarity);
    ASSIGN(searchTerm, term);
    ASSIGN(field, [searchTerm field]);

    //The prefix could be longer than the word.
    //It's kind of silly though.  It means we must match the entire word.
	int fullSearchTermLength = [[searchTerm text] length];
	int realPrefixLength = (prefixLength > fullSearchTermLength) ? fullSearchTermLength : prefixLength;

    //this.text = searchTerm.text().substring(realPrefixLength);
	ASSIGN(text, [[searchTerm text] substringFromIndex: realPrefixLength]);
	ASSIGN(prefix, [[searchTerm text] substringToIndex: realPrefixLength]);

    [self initializeMaxDistances];
	[self initDistanceArray];

	LCTerm *tt = [[LCTerm alloc] initWithField: [searchTerm field] text: prefix];
	[self setEnumerator: [reader termEnumeratorWithTerm: tt]];
	DESTROY(tt);
	return self;
}

- (void) dealloc
{
	DESTROY(maxDistances);
	DESTROY(searchTerm);
	DESTROY(field);
	DESTROY(text);
	DESTROY(prefix);
	[super dealloc];
}

  /**
   * The termCompare method in FuzzyTermEnum uses Levenshtein distance to 
   * calculate the distance between the given term and the comparing term. 
   */
- (BOOL) isEqualToTerm: (LCTerm *) term
{
	if (([field isEqualToString: [term field]]) && 
		(([[term text] hasPrefix: prefix]) || ([prefix length] == 0 /* no prefix */)))
	{
		NSString *target = [[term text] substringFromIndex: [prefix length]];
		similarity = [self similarity: target];
		return (similarity > minimumSimilarity) ? YES : NO;
	}
	endEnum = YES;
	return NO;
}

- (float) difference
{
    return (float)((similarity - minimumSimilarity) * scale_factor);
}
  
- (BOOL) endOfEnumerator
{
    return endEnum;
}
  
  /******************************
   * Compute Levenshtein distance
   ******************************/

- (void) initDistanceArray
{
	/*
	d_count_row = [text length];
	d_count_column = TYPICAL_LONGEST_WORD_IN_INDEX;
	d = malloc(sizeof(int)* d_count_row * d_count_column);
	 */
}

  /**
   * <p>Similarity returns a number that is 1.0f or less (including negative numbers)
   * based on how similar the Term is compared to a target term.  It returns
   * exactly 0.0f when
   * <pre>
   *    editDistance &lt; maximumEditDistance</pre>
   * Otherwise it returns:
   * <pre>
   *    1 - (editDistance / length)</pre>
   * where length is the length of the shortest term (text or target) including a
   * prefix that are identical and editDistance is the Levenshtein distance for
   * the two words.</p>
   *
   * <p>Embedded within this algorithm is a fail-fast Levenshtein distance
   * algorithm.  The fail-fast algorithm differs from the standard Levenshtein
   * distance algorithm in that it is aborted if it is discovered that the
   * mimimum distance between the words is greater than some threshold.
   *
   * <p>To calculate the maximum distance threshold we use the following formula:
   * <pre>
   *     (1 - minimumSimilarity) * length</pre>
   * where length is the shortest term including any prefix that is not part of the
   * similarity comparision.  This formula was derived by solving for what maximum value
   * of distance returns false for the following statements:
   * <pre>
   *   similarity = 1 - ((float)distance / (float) (prefixLength + Math.min(textlen, targetlen)));
   *   return (similarity > minimumSimilarity);</pre>
   * where distance is the Levenshtein distance for the two words.
   * </p>
   * <p>Levenshtein distance (also known as edit distance) is a measure of similiarity
   * between two strings where the distance is measured as the number of character
   * deletions, insertions or substitutions required to transform one string to
   * the other string.
   * @param target the target word or phrase
   * @return the similarity,  0.0 or less indicates that it matches less than the required
   * threshold and 1.0 indicates that the text and target are identical
   */
- (float) similarity: (NSString *) target
{
	float score = 0.0f;
	int m = [target length];
	int n = [text length];
	if (n == 0) {
		//we don't have anything to compare.  That means if we just add
		//the letters for m we get the new word
		score = ([prefix length] == 0) ? 0.0f : (1.0f - ((float) m / [prefix length]));
		return score;
    }
    if (m == 0) 
	{
      score = ([prefix length] == 0) ? 0.0f : (1.0f - ((float) n / [prefix length]));
	return score;
    }

	int maxDistance = [self maxDistance:m];

    if (maxDistance < abs(m-n)) {
      //just adding the characters of m to n or vice-versa results in
      //too many edits
      //for example "pre" length is 3 and "prefixes" length is 8.  We can see that
      //given this optimal circumstance, the edit distance cannot be less than 5.
      //which is 8-3 or more precisesly Math.abs(3-8).
      //if our maximum edit distance is 4, then we can discard this word
      //without looking at it.
      return 0.0f;
    }

    //let's make sure we have enough room in our array to do the distance calculations.
	int dn = [text length];
	int dm = (TYPICAL_LONGEST_WORD_IN_INDEX < m) ? m: TYPICAL_LONGEST_WORD_IN_INDEX;
	//int d[dn][dm];
	int *d = malloc(sizeof(int)*dn*dm);

	int d_value;
	/*
	if (d_count_column <= m) {
		[self growDistanceArray: m];
    }
	 */

    // init matrix d
	int i, j;
    for (i = 0; i <= n; i++) {
	// d[i][0] = i;
	*(d+i*dn) = i;
    }

    for (j = 0; j <= m; j++) {
	// d[0][j] = j;
	*(d+j) = j;
    }
    
    // start computing edit distance
    for (i = 1; i <= n; i++) {
		int bestPossibleEditDistance = m;
		unichar s_i = [text characterAtIndex: (i - 1)];
		for ( j = 1; j <= m; j++) {
			if (s_i != [target characterAtIndex: (j-1)]) {
//				d[i][j] = minOfThree(d[i-1][j], d[i][j-1], d[i-1][j-1])+1;
				*(d+i*dn+j) = minOfThree(*(d+(i-1)*dn+j), *(d+i*dn+(j-1)), *(d+(i-1)*dn+j-1))+1;
			} else {
//				d[i][j] = minOfThree(d[i-1][j]+1, d[i][j-1]+1, d[i-1][j-1]);
                                *(d+i*dn+j) = minOfThree((*(d+(i-1)*dn+j))+1, (*(d+i*dn+(j-1)))+1, *(d+(i-1)*dn+j-1));

			}
			d_value = *(d+i*dn+j) /*d[i][j]*/;
			bestPossibleEditDistance = minOfTwo(bestPossibleEditDistance, d_value);
		}

      //After calculating row i, the best possible edit distance
      //can be found by found by finding the smallest value in a given column.
      //If the bestPossibleEditDistance is greater than the max distance, abort.
		
		if (i > maxDistance && bestPossibleEditDistance > maxDistance) {  //equal is okay, but not greater
        //the closest the target can be to the text is just too far away.
        //this target is leaving the party early.
			free(d);
			return 0.0f;
		}
	}

    // this will return less than 0.0 when the edit distance is
    // greater than the number of characters in the shorter word.
    // but this was the formula that was previously used in FuzzyTermEnum,
    // so it has not been changed (even though minimumSimilarity must be
    // greater than 0.0)

    /* LuceneKit: the conversion doesn't work on Debian/PowerPC, at least */
    d_value = *(d+n*dn+m)/*d[n][m]*/;
    float first_score = [prefix length] + minOfTwo(n, m);
    score = 1.0f - d_value / first_score;
//    score = 1.0f - ((float)d_score / (float)([prefix length] + minOfTwo(n, m)));
    free(d);
    return score;
}

  /**
   * Grow the second dimension of the array, so that we can calculate the
   * Levenshtein difference.
   */
- (void) growDistanceArray: (int) m
{
	/*
	if (d)
		free(d);
	d_count_column = m+1;
	d = malloc(sizeof(int)*d_count_row*d_count_column);
	 */
}
	/*
  private void growDistanceArray(int m) {
    for (int i = 0; i < d.length; i++) {
      d[i] = new int[m+1];
    }
	  */

  /**
   * The max Distance is the maximum Levenshtein distance for the text
   * compared to some other value that results in score that is
   * better than the minimum similarity.
   * @param m the length of the "other value"
   * @return the maximum levenshtein distance that we care about
   */
- (int) maxDistance: (int) m
{
    return (m < [maxDistances count]) ? [[maxDistances objectAtIndex: m] intValue] : [self calculateMaxDistance: m];
  }

- (void) initializeMaxDistances
{
	int i;
    for (i = 0; i < TYPICAL_LONGEST_WORD_IN_INDEX /*maxDistances.length*/; i++) {
		[maxDistances addObject: [NSNumber numberWithInt: [self calculateMaxDistance: i]]];
    }
}
  
- (int) calculateMaxDistance: (int) m
{
    return (int) ((1-minimumSimilarity) * (minOfTwo([text length], m) + [prefix length]));
  }

@end
