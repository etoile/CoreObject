#ifndef __LUCENE_ANALYSIS_TOKEN_FILTER__
#define __LUCENE_ANALYSIS_TOKEN_FILTER__

#include <Foundation/Foundation.h>
#include "LCTokenStream.h"

/* A filter for token stream */
@interface LCTokenFilter: LCTokenStream
{
	LCTokenStream *input;
}

- (id) initWithTokenStream: (LCTokenStream *) input;

@end

#endif /* __LUCENE_ANALYSIS_TOKEN_FILTER__ */
