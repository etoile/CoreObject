#ifndef __LUCENE_JAVA_STRING_READER__
#define __LUCENE_JAVA_STRING_READER__

#include "LCReader.h"

@interface LCStringReader: NSObject <LCReader>
{
	unsigned int pos;
	NSString * source; 
}

- (id) initWithString: (NSString *) s;
@end

#endif /* __LUCENE_JAVA_STRING_READER__ */

