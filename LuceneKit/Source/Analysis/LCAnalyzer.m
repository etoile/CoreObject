#include "LCAnalyzer.h"
#include "LCReader.h"
#include "GNUstep.h"

@implementation LCAnalyzer
/** An Analyzer builds TokenStreams, which analyze text.  It thus represents a
*  policy for extracting index terms from text.
*  <p>
*  Typical implementations first build a Tokenizer, which breaks the stream of
*  characters from the Reader into raw Tokens.  One or more TokenFilters may
*  then be applied to the output of the Tokenizer.
*  <p>
*/

/** <override-subclass /> Creates a TokenStream which tokenizes all the text in the provided
Reader.  Default implementation forwards to tokenStream(Reader) for 
compatibility with older version.  Override to allow Analyzer to choose 
strategy based on document and/or field.  Must be able to handle null
field name for backward compatibility. */
- (LCTokenStream *) tokenStreamWithField: (NSString *) name
								  reader: (id <LCReader>) reader
{
	return nil;
}

/**
 * Invoked, by DocumentWriter, before indexing a Field instance if
 * terms have already been added to that field.  This allows custom
 * analyzers to place an automatic position increment gap between
 * Field instances using the same field name.  The default value
 * position increment gap is 0.  With a 0 position increment gap and
 * the typical default token position increment of 1, all terms in a field,
 * including across Field instances, are in successive positions, allowing
 * exact PhraseQuery matches, for instance, across Field instance boundaries.
 *
 * @param fieldName Field name being indexed.
 * @return position increment gap, added to the next token emitted from {@link #tokenStream(String,Reader)}
 */
- (int) positionIncrementGap: (NSString *) fieldName
{
	return 0;
}


@end

