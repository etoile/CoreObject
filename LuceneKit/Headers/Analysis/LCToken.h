#ifndef __LUCENE_ANALYSIS_TOKEN__
#define __LUCENE_ANALYSIS_TOKEN__

#include <Foundation/Foundation.h>

/** A Token is an occurence of a term from the text of a field.  It consists of
a term's text, the start and end offset of the term in the text of the field,
and a type string.

The start and end offsets permit applications to re-associate a token with
its source text, e.g., to display highlighted query terms in a document
browser, or to show matching text fragments in a KWIC (KeyWord In Context)
display, etc.

The type is an interned string, assigned by a lexical analyzer
(a.k.a. tokenizer), naming the lexical or syntactic class that the token
belongs to.  For example an end of sentence marker token might be implemented
with type "eos".  The default token type is "word".  */

@interface LCToken: NSObject
{
	NSString *termText;				  // the text of the term
	int startOffset;				  // start in source text
	int endOffset;				  // end in source text
	NSString *type;				  // lexical type
	int positionIncrement;
}

- (id) initWithText: (NSString *) text
              start: (int) start end: (int) end;
- (id) initWithText: (NSString *) text
              start: (int) start end: (int) end
			   type: (NSString *) type;
- (void) setPositionIncrement: (int) pos;
- (int) positionIncrement;
- (NSString *) termText; 
- (void) setTermText: (NSString *) termText;
- (int) startOffset; 
- (int) endOffset;
- (NSString *) type;

@end

#endif /* __LUCENE_ANALYSIS_TOKEN__ */
