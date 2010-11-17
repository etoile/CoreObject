#ifndef __LUCENE_INDEX_TERM_VECTOR_OFFSET_INFO__
#define __LUCENE_INDEX_TERM_VECTOR_OFFSET_INFO__

#include <Foundation/Foundation.h>

@interface LCTermVectorOffsetInfo: NSObject
{
	int startOffset, endOffset;
}

- (id) initWithStartOffset: (int) so endOffset: (int) eo;
- (int) endOffset;
- (void) setEndOffset: (int) eo;
- (int) startOffset;
- (void) setStartOffset: (int) so;

@end

#endif /* __LUCENE_INDEX_TERM_VECTOR_OFFSET_INFO__ */
