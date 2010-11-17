#include "LCWhitespaceTokenizer.h"

/** A WhitespaceTokenizer is a tokenizer that divides text at whitespace.
* Adjacent sequences of non-Whitespace characters form tokens. */
@implementation LCWhitespaceTokenizer

- (BOOL) characterIsPartOfToken: (char) c
{
	/** Collects only characters which do not satisfy
	* {@link Character#isWhitespace(char)}.*/
	NSCharacterSet *charSet = [NSCharacterSet whitespaceCharacterSet];
	return ![charSet characterIsMember: (unichar) c];
}

@end
