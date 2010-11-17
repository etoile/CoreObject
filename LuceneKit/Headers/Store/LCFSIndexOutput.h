#ifndef __LUCENE_STORE_FSINDEX_OUTPUT__
#define __LUCENE_STORE_FSINDEX_OUTPUT__

#include "LCIndexOutput.h"

@interface LCFSIndexOutput: LCIndexOutput
{
	NSFileHandle *handle;
	NSString *path;
	BOOL isClosed;
}

- (id) initWithFile: (NSString *) absolutePath;
@end
#endif /* __LUCENE_STORE_FSINDEX_OUTPUT__ */
