#ifndef __LUCENE_STORE_RAM_DIRECTORY__
#define __LUCENE_STORE_RAM_DIRECTORY__

#include "LCDirectory.h"

@interface LCRAMDirectory: NSObject <LCDirectory>
{
	NSMutableDictionary *files;
}

- (id) initWithDirectory: (id <LCDirectory>) dir;
- (id) initWithDirectory: (id <LCDirectory>) dir
                   close: (BOOL) closeDirectory;
- (id) initWithPath: (NSString *) absolutePath;

@end

#endif /* __LUCENE_STORE_RAM_DIRECTORY__ */
