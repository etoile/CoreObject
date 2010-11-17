#include "LCFilteredTermEnum.h"
#include "GNUstep.h"

/** Abstract class for enumerating a subset of all terms. 

<p>Term enumerations are always ordered by Term.compareTo().  Each term in
the enumeration is greater than all that precede it.  */

@implementation LCFilteredTermEnumerator

- (void) dealloc
{
  DESTROY(actualEnum);
  DESTROY(currentTerm);
  [super dealloc];
}

/** Equality compare on the term */
//protected abstract boolean termCompare(Term term);
- (BOOL) isEqualToTerm: (LCTerm *) term { return NO; }

/** Equality measure on the term */
- (float) difference { return -1.0; }
	
/** Indiciates the end of the enumeration has been reached */
//    protected abstract boolean endEnum();
- (BOOL) endOfEnumerator { return NO; }
    
- (void) setEnumerator: (LCTermEnumerator *) ae
{
	ASSIGN(actualEnum, ae);
	// Find the first term that matches
	LCTerm *term = [actualEnum term];
	if (term != nil && [self isEqualToTerm: term])
		ASSIGN(currentTerm, term);
	else
		[self hasNextTerm];
}

/** 
 * Returns the docFreq of the current Term in the enumeration.
 * Returns -1 if no Term matches or all terms have been enumerated.
 */
- (long) documentFrequency
{
	if (actualEnum == nil) return -1;
	return [actualEnum documentFrequency];
}
    
/** Increments the enumeration to the next element.  True if one exists. */
- (BOOL) hasNextTerm
{
	if (actualEnum == nil) return NO;
	DESTROY(currentTerm);
	while (currentTerm == nil) {
		if ([self endOfEnumerator] == YES) return NO;
		if ([actualEnum hasNextTerm]) {
			LCTerm *term = [actualEnum term];
			if ([self isEqualToTerm: term]) {
				ASSIGN(currentTerm, term);
				return YES;
			}
		}
		else return NO;
	}
	DESTROY(currentTerm);
	return NO;
}
    
/** Returns the current Term in the enumeration.
 * Returns null if no Term matches or all terms have been enumerated. */
- (LCTerm *) term
{
	return currentTerm;
}
	
/** Closes the enumeration to further activity, freeing resources.  */
- (void) close
{
	[actualEnum close];
	DESTROY(currentTerm);
	DESTROY(actualEnum);
}

@end
