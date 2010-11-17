#ifndef __LUCENE_INDEX_SEGMENT_READER__
#define __LUCENE_INDEX_SEGMENT_READER__

#include "LCIndexReader.h"
#include "LCTermFreqVector.h"
#include "LCFieldInfos.h"
#include "LCCompoundFileReader.h"
#include "LCSegmentInfo.h"
#include "LCTermInfosReader.h"
#include "LCBitVector.h"

@class LCFieldsReader;
@class LCTermVectorsReader;

//static LCTermVectorsReader *tvReader;

@interface LCSegmentReader: LCIndexReader
{
	NSString *segment;
	LCFieldInfos *fieldInfos;
	LCFieldsReader *fieldsReader;
	LCTermInfosReader *tis;
	LCTermVectorsReader *termVectorsReaderOrig;
	//ThreadLocal termVectorsLocal = new ThreadLocal;
	LCBitVector *deletedDocs;
	BOOL deletedDocsDirty;
	BOOL normsDirty;
	BOOL undeleteAll;
	
	NSMutableDictionary *norms;
	
	LCIndexInput *freqStream;
	LCIndexInput *proxStream;
	LCCompoundFileReader *cfsReader;

	NSData *ones;
}

+ (id) segmentReaderWithInfo: (LCSegmentInfo *) si;
+ (id) segmentReaderWithInfos: (LCSegmentInfos *) sis 
                         info: (LCSegmentInfo *) si
						close: (BOOL) closeDir;
+ (id) segmentReaderWithDirectory: (id <LCDirectory>) dir
							 info: (LCSegmentInfo *) si
							infos: (LCSegmentInfos *) sis
							close: (BOOL) closeDir
							owner: (BOOL) ownDir;
+ (BOOL) hasDeletions: (LCSegmentInfo *) si;
+ (BOOL) usesCompoundFile: (LCSegmentInfo *) si;
+ (BOOL) hasSeparateNorms: (LCSegmentInfo *) si;
+ (NSData *) createFakeNorms: (int) size;
- (NSArray *) files;
- (LCBitVector*) deletedDocs;
- (LCTermInfosReader *) termInfosReader;
- (LCIndexInput *) freqStream;
- (LCIndexInput *) proxStream;
- (LCFieldInfos *) fieldInfos;
- (NSString *) segment;
- (LCCompoundFileReader *) cfsReader;

@end


#endif /* __LUCENE_INDEX_SEGMENT_READER__ */
