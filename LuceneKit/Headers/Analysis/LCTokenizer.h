#ifndef __LUCENE_ANALYSIS_TOKENIZER__
#define __LUCENE_ANALYSIS_TOKENIZER__

#include <Foundation/Foundation.h>
#include "LCTokenStream.h"
#include "LCReader.h"

/* A token stream specified for LCReader */
@interface LCTokenizer: LCTokenStream
{
	/** The text source for this Tokenizer. */
	id <LCReader> input;
}

- (id) initWithReader: (id <LCReader>) input;

@end

#endif /* __LUCENE_ANALYSIS_TOKENIZER__ */
