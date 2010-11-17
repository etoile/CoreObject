#ifndef __LUCENE_INDEX_COMPOUND_FILE_READER__
#define __LUCENE_INDEX_COMPOUND_FILE_READER__

#include "LCDirectory.h"
#include <Foundation/Foundation.h>

@interface LCCompoundFileReader: NSObject <LCDirectory>
{
	id <LCDirectory> directory;
	NSString *fileName;
	LCIndexInput *stream;
	NSMutableDictionary *entries;
}
- (id) initWithDirectory: (id <LCDirectory>) dir
					name: (NSString *) name;
- (id <LCDirectory>) directory;
- (NSString *) name;
	//- makeLock: (NSString *) name;

@end

@interface LCCSIndexInput: LCIndexInput <NSCopying>
{
	LCCompoundFileReader *reader;
	LCIndexInput *base;
	long long fileOffset;
	long long length;
	long long filePointer;
}
- (id) initWithCompoundFileReader: (LCCompoundFileReader *) r
					   indexInput: (LCIndexInput *) base offset: (long long) fileOffset
						   length: (long long) length;
@end

#endif /* __LUCENE_INDEX_COMPOUND_FILE_READER__ */
