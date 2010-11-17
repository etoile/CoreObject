#ifndef __LUCENE_INDEX_TERM_FREQ_VECTOR__
#define __LUCENE_INDEX_TERM_FREQ_VECTOR__

#include <Foundation/Foundation.h>

/** Provides access to stored term vector of 
*  a document field.
*/
@protocol LCTermFrequencyVector <NSObject>
/**
* 
 * @return The field this vector is associated with.
 * 
 */ 
- (NSString *) field;

	/** 
	* @return The number of terms in the term vector.
	*/
- (int) size;

	/** 
	* @return An Array of term texts in ascending order.
	*/
- (NSArray *) allTerms;
	//  public String[] getTerms();


	/** Array of term frequencies. Locations of the array correspond one to one
	*  to the terms in the array obtained from <code>getTerms</code>
	*  method. Each location in the array contains the number of times this
	*  term occurs in the document or the document field.
	*/
	// NSArray of NSNumber
- (NSArray *) allTermFrequencies;
	//  public int[] getTermFrequencies();


	/** Return an index in the term numbers array returned from
	*  <code>getTerms</code> at which the term with the specified
	*  <code>term</code> appears. If this term does not appear in the array,
	*  return -1.
	*/
- (int) indexOfTerm: (NSString *) term;


	/** Just like <code>indexOf(int)</code> but searches for a number of terms
	*  at the same time. Returns an array that has the same size as the number
	*  of terms searched for, each slot containing the result of searching for
	*  that term number.
	*
	*  @param terms array containing terms to look for
	*  @param start index in the array where the list of terms starts
	*  @param len the number of terms in the list
	*/
	// NSArray of NSNumber
- (NSIndexSet *) indexesOfTerms: (NSArray *) terms
						  start: (int) start length: (int) len;
	//  public int[] indexesOf(String[] terms, int start, int len);

@end

#endif /* __LUCENE_INDEX_TERM_FREQ_VECTOR__ */
