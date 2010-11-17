#ifndef __LUCENE_INDEX_SEGMENT_MERGER__
#define __LUCENE_INDEX_SEGMENT_MERGER__

#include <Foundation/Foundation.h>
#include "LCDirectory.h"

@class LCFieldInfos;
@class LCIndexOutput;
@class LCIndexWriter;
@class LCIndexReader;
@class LCTermInfosWriter;
@class LCSegmentMergeQueue;
@class LCTermInfo;
@class LCRAMOutputStream;

@interface LCSegmentMerger: NSObject
{
	id <LCDirectory> directory;
	NSString *segment;
	int termIndexInterval;
	NSMutableArray *readers;
	LCFieldInfos *fieldInfos;
	NSArray *COMPOUND_EXTENSIONS;
	NSArray *VECTOR_EXTENSIONS;
	
	LCIndexOutput *freqOutput;
	LCIndexOutput *proxOutput;
	LCTermInfosWriter *termInfosWriter;
	int skipInterval;
	LCSegmentMergeQueue *queue;
	
	LCRAMOutputStream *skipBuffer;
	int lastSkipDoc;
	unsigned long long lastSkipFreqPointer;
	unsigned long long lastSkipProxPointer;
}
// This ctor used only by test code
- (id) initWithDirectory: (id <LCDirectory>) dir name: (NSString *) name;
- (id) initWithIndexWriter: (LCIndexWriter *) writer name: (NSString *) name;
- (void) addIndexReader: (LCIndexReader *) reader;
- (LCIndexReader *) segmentReader: (int) i;
- (int) merge;
- (void) closeReaders;
- (NSArray *) createCompoundFile: (NSString *) fileName;

@end
#endif /* __LUCENE_INDEX_SEGMENT_MERGER__ */
