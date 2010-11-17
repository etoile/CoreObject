#include "LCTokenStream.h"

/** A TokenStream enumerates the sequence of tokens, either from
fields of a document or from query text.
<p>
This is an abstract class.  Concrete subclasses are:
<ul>
<li>{@link Tokenizer}, a TokenStream
whose input is a Reader; and
<li>{@link TokenFilter}, a TokenStream
whose input is another TokenStream.
</ul>
*/

@implementation LCTokenStream

- (LCToken *) nextToken
{
	return nil;
}

- (void) close
{
}

@end
