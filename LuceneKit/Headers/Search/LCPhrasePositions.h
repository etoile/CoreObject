#ifndef __LUCENE_SEARCH_PHRASE_POSITIONS__
#define __LUCENE_SEARCH_PHRASE_POSITIONS__

#include <Foundation/Foundation.h>

@interface LCPhrasePositions: NSObject
{
	int doc;
	int position;
	int count;
	int offset;
	id <LCTermPositions> *tp;
	LCPhrasePositions *next;
}

- (id) initWithTermPositions: (id <LCTermPositions>) t offset: (int) o;
- (BOOL) next;
- (BOOL) skipTo: (int) target;
- (void) firstPosition;
- (BOOL) nextPosition;

@end

#endif /* __LUCENE_SEARCH_PHRASE_POSITIONS__ */
