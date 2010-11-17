#include "LCLowerCaseTokenizer.h"

/**
* LowerCaseTokenizer performs the function of LetterTokenizer
 * and LowerCaseFilter together.  It divides text at non-letters and converts
 * them to lower case.  While it is functionally equivalent to the combination
 * of LetterTokenizer and LowerCaseFilter, there is a performance advantage
 * to doing the two tasks at once, hence this (redundant) implementation.
 * <P>
 * Note: this does a decent job for most European languages, but does a terrible
 * job for some Asian languages, where words are not separated by spaces.
 */
@implementation LCLowerCaseTokenizer

- (char) normalize: (char) c
{
	if ((c <= 'Z') && (c >= 'A'))
		return (c-'A'+'a');
	else
		return c;
}

@end
