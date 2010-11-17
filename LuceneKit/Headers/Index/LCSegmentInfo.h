#ifndef __LUCENE_INDEX_SEGMENT_INFO__
#define __LUCENE_INDEX_SEGMENT_INFO__

#include <Foundation/Foundation.h>
#include "LCDirectory.h"

@interface LCSegmentInfo: NSObject
{
	NSString *name;             // unique name in dir
	int docCount;               // number of docs in seg
	id <LCDirectory> dir;       // where segment resides
}

- (id) initWithName: (NSString *) name
  numberOfDocuments: (int) count
		  directory: (id <LCDirectory>) dir;
- (NSString *) name;
- (int) numberOfDocuments;
- (id <LCDirectory>) directory;

@end

#endif /* __LUCENE_INDEX_SEGMENT_INFO__ */
