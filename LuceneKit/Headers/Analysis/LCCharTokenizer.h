#ifndef __LUCENE_ANALYSIS_CHAR_TOKENIZER__
#define __LUCENE_ANALYSIS_CHAR_TOKENIZER__

#include "LCTokenizer.h"

#define MAX_WORD_LEN 256
#define IO_BUFFER_SIZE 1024

@interface LCCharTokenizer: LCTokenizer
{
	int offset, bufferIndex, dataLen;
	unichar buffer[MAX_WORD_LEN], ioBuffer[IO_BUFFER_SIZE];
}

/** Check whether c belongs to token. Return NO is c is used to break tokens. */
- (BOOL) characterIsPartOfToken: (char) c;
/** Normalize a charactor. Ex. 'ue' in German will be 'u' */
- (char) normalize: (char) c;

@end

#endif /* __LUCENE_ANALYSIS_CHAR_TOKENIZER__ */
