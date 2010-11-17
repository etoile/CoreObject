#include "LCLetterTokenizer.h"

/** A LetterTokenizer is a tokenizer that divides text at non-letters.  That's
to say, it defines tokens as maximal strings of adjacent letters, as defined
by java.lang.Character.isLetter() predicate.

Note: this does a decent job for most European languages, but does a terrible
job for some Asian languages, where words are not separated by spaces. */

@implementation LCLetterTokenizer: LCCharTokenizer 

- (BOOL) characterIsPartOfToken: (char) c
{
	/** Collects only characters which satisfy
	* {@link Character#isLetter(char)}.*/
	NSCharacterSet *charSet = [NSCharacterSet letterCharacterSet];
	return [charSet characterIsMember: (unichar) c];
}
@end
