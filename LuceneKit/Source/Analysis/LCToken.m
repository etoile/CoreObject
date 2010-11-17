#include "LCToken.h"
#include "GNUstep.h"

@implementation LCToken

- (id) init
{
	self = [super init];
	ASSIGN(type, [NSString stringWithCString: "word"]);
	positionIncrement = 1;
	return self;
}

/** Constructs a Token with the given term text, and start & end offsets.
The type defaults to "word." */
- (id) initWithText: (NSString *) text
              start: (int) start end: (int) end;
{
	self = [self init];
	ASSIGN(termText, AUTORELEASE([text copy]));
	startOffset = start;
	endOffset = end;
	return self;
}

/** Constructs a Token with the given text, start and end offsets, & type. */
- (id) initWithText: (NSString *) text
              start: (int) start end: (int) end
               type: (NSString *) t
{
	self = [self init];
	ASSIGN(termText, AUTORELEASE([text copy]));
	startOffset = start;
	endOffset = end;
	ASSIGN(type, t);
	return self;
}

- (void) dealloc
{
	DESTROY(termText);
	DESTROY(type);
	[super dealloc];
}

/** Set the position increment.  This determines the position of this token
* relative to the previous Token in a {@link TokenStream}, used in phrase
* searching.
*
* <p>The default value is one.
*
* <p>Some common uses for this are:<ul>
*
* <li>Set it to zero to put multiple terms in the same position.  This is
* useful if, e.g., a word has multiple stems.  Searches for phrases
* including either stem will match.  In this case, all but the first stem's
* increment should be set to zero: the increment of the first instance
* should be one.  Repeating a token with an increment of zero can also be
* used to boost the scores of matches on that token.
*
* <li>Set it to values greater than one to inhibit exact phrase matches.
* If, for example, one does not want phrases to match across removed stop
* words, then one could build a stop word filter that removes stop words and
* also sets the increment to the number of stop words removed before each
* non-stop word.  Then exact phrase queries will only match when the terms
* occur with no intervening stop words.
*
* </ul>
* @see org.apache.lucene.index.TermPositions
*/
- (void) setPositionIncrement: (int) pos
{
	if (positionIncrement < 0)
		[NSException raise: @"IllegalArgumentException"
					format: @"Increment must be zero or greater: %d", pos];
	
	positionIncrement = pos;
}

/** Returns the position increment of this Token.
* @see #setPositionIncrement
*/
- (int) positionIncrement
{ 
	return positionIncrement; 
}

/** Returns the Token's term text. */
- (NSString *) termText
{ 
	return termText; 
}

- (void) setTermText: (NSString *) text
{
	ASSIGNCOPY(termText, text);
}

/** Returns this Token's starting offset, the position of the first character
corresponding to this token in the source text.

Note that the difference between endOffset() and startOffset() may not be
equal to termText.length(), as the term text may have been altered by a
stemmer or some other filter. */
- (int) startOffset
{ 
	return startOffset; 
}

/** Returns this Token's ending offset, one greater than the position of the
last character corresponding to this token in the source text. */
- (int) endOffset
{ 
	return endOffset; 
}

/** Returns this Token's lexical type.  Defaults to "word". */
- (NSString *) type
{ 
	return type; 
}

- (NSString *) description
{
#if 1
	return [NSString stringWithFormat: @"LCToken<0x%x> %@", self, termText];
#else
    StringBuffer sb = new StringBuffer();
    sb.append("(" + termText + "," + startOffset + "," + endOffset);
    if (!type.equals("word"))
      sb.append(",type="+type);
    if (positionIncrement != 1)
      sb.append(",posIncr="+positionIncrement);
    sb.append(")");
    return sb.toString();
  }
#endif
}

@end
