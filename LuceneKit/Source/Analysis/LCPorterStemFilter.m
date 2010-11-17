#include "LCPorterStemFilter.h"

/** Transforms the token stream as per the Porter stemming algorithm.
Note: the input to the stemming filter must already be in lower case,
so you will need to use LowerCaseFilter or LowerCaseTokenizer farther
down the Tokenizer chain in order for this to work properly!
<P>
To use this filter with other analyzers, you'll want to write an
Analyzer class that sets up the TokenStream chain as you want it.
To use this with LowerCaseTokenizer, for example, you'd write an
analyzer like this:
<P>
<PRE>
class MyAnalyzer extends Analyzer {
	public final TokenStream tokenStream(String fieldName, Reader reader) {
        return new PorterStemFilter(new LowerCaseTokenizer(reader));
	}
}
</PRE>
*/
@implementation LCPorterStemFilter

- (id) initWithTokenStream: (LCTokenStream *) stream
{
	self = [super initWithTokenStream: stream];
	st = create_stemmer();
	return self;
}

- (void) dealloc
{
	free_stemmer(st);
	[super dealloc];
}

/** Returns the next input Token, after being stemmed */
- (LCToken *) nextToken
{
	LCToken *token = [input nextToken];
	if (token == nil)
		return nil;
	else 
    {
		// FIXME: not i18n compatible
		NSString *term = [token termText];
		int k = stem(st, (char *)[term cString], [term length]);
		NSString *sub = [term substringToIndex: k];
		if (sub != term) // Yes, I mean object reference comparison here
			[token setTermText: sub];
		return token;
    }
}

@end
