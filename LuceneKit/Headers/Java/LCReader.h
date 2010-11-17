#ifndef __LUCENE_JAVA_READER__
#define __LUCENE_JAVA_READER__

#include <Foundation/Foundation.h>

/* A clone of java reader class */
@protocol LCReader <NSObject>

- (void) close;
- (int) read;
- (int) read: (unichar *) buf length: (unsigned int) len;
- (BOOL) ready;
- (long) skip: (long) n;

@end

#endif /* __LUCENE_JAVA_READER__ */
