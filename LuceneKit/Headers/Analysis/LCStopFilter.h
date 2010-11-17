#ifndef __LUCENE_ANALYSIS_STOP_FILTER__
#define __LUCENE_ANALYSIS_STOP_FILTER__

#include "LCTokenFilter.h"

@interface LCStopFilter: LCTokenFilter
{
	NSMutableSet *stopWords;
}

+ (NSSet *) makeStopSet: (NSArray *) sw;

- (id) initWithTokenStream: (LCTokenStream *) stream
          stopWordsInArray: (NSArray *) sw;
#if 0
- (id) initWithTokenStream: (LCTokenStream *) stream
     stopWordsInDictionary: (NSDictionary *) st;
#endif
- (id) initWithTokenStream: (LCTokenStream *) stream 
            stopWordsInSet: (NSSet *) sw;

@end

#endif /* __LUCENE_ANALYSIS_STOP_FILTER__ */
