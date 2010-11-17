#ifndef __LUCENE_STORE_FSDIRECTORY__
#define __LUCENE_STORE_FSDIRECTORY__

#include <Foundation/Foundation.h>
#include "LCDirectory.h"

@interface LCFSDirectory: NSObject <LCDirectory>
{
	NSFileManager *manager;
	NSString *path;
}
+ (LCFSDirectory *) directoryAtPath: (NSString *) absolutePath
                          create: (BOOL) create;

- (id) initWithPath: (NSString *) absolutePath create: (BOOL) b;
@end
#endif /* __LUCENE_STORE_FSDIRECTORY__ */
