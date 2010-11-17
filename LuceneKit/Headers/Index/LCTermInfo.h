#ifndef __LUCENE_INDEX_TERM_INFO__
#define __LUCENE_INDEX_TERM_INFO__

#include <Foundation/Foundation.h>

@interface LCTermInfo: NSObject <NSCopying>
{
	long docFreq; // VInt
	long long freqPointer; //VLong
	long long proxPointer; //VLong
	long skipOffset; //VLong
}

- (id) initWithDocFreq: (long) df 
           freqPointer: (long long) fq 
		   proxPointer: (long long) pp;
- (id) initWithTermInfo: (LCTermInfo *) ti;
- (void) setTermInfo: (LCTermInfo *) ti;

	/* Accessory */
- (long) documentFrequency;
- (long long) freqPointer;
- (long long) proxPointer;
- (long ) skipOffset;
- (void) setDocumentFrequency: (long) doc;
- (void) setFreqPointer: (long long) freq;
- (void) setProxPointer: (long long) prox;
- (void) setSkipOffset: (long) skip;

@end

#endif /* __LUCENE_INDEX_TERM_INFO__ */
