#include "LCTokenFilter.h"
#include "GNUstep.h"

@implementation LCTokenFilter

/** A TokenFilter is a TokenStream whose input is another token stream.
<p>
This is an abstract class.
*/

/** Construct a token stream filtering the given input. */
- (id) initWithTokenStream: (LCTokenStream *) i
{
	self = [self init];
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

