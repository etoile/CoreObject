#include "LCTokenizer.h"
#include "LCReader.h"
#include "GNUstep.h"

@implementation LCTokenizer

/** A Tokenizer is a TokenStream whose input is a Reader.
<p>
This is an abstract class.
*/

/** Construct a token stream processing the given input. */
- (id) initWithReader: (id <LCReader>) i
{
	self = [super init];
	ASSIGN(input, i);
	return self;
}

- (void) dealloc
{
	DESTROY(input);
	[super dealloc];
}

- (void) close
{
	[input close];
}

@end
