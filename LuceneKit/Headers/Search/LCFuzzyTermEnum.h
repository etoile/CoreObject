#ifndef __LUCENE_SEARCH_FUZZY_TERM_ENUM__
#define __LUCENE_SEARCH_FUZZY_TERM_ENUM__

/* This should be somewhere around the average long word.
* If it is longer, we waste time and space. If it is shorter, we waste a
* little bit of time growing the array as we encounter longer words.
*/
static const int TYPICAL_LONGEST_WORD_IN_INDEX = 19;

int min(int a, int b, int c);

#include "LCFilteredTermEnum.h"

@class LCTerm;
@class LCIndexReader;

@interface LCFuzzyTermEnumerator: LCFilteredTermEnumerator
{
	/* Allows us save time required to create a new array
	* everytime similarity is called.
	*/	
	/*
	int *d;
	int d_count_row;
	int d_count_column;
	 */
	float similarity;
	BOOL endEnum;
	LCTerm *searchTerm;
	NSString *field;
	NSString *text;
	NSString *prefix;
	
	float minimumSimilarity;
	float scale_factor;
	NSMutableArray *maxDistances;
}

- (id) initWithReader: (LCIndexReader *) reader term: (LCTerm *) term;
- (id) initWithReader: (LCIndexReader *) reader term: (LCTerm *) term 
		   similarity: (float) similarity;
- (id) initWithReader: (LCIndexReader *) reader term: (LCTerm *) term 
		   similarity: (float) similarity prefixLength: (int) prefixLength;

@end

#endif /* __LUCENE_SEARCH_FUZZY_TERM_ENUM__ */
