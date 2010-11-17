#ifndef __LUCENE_STORE_RAM_FILE__
#define __LUCENE_STORE_RAM_FILE__

#include <Foundation/Foundation.h>

@interface LCRAMFile: NSObject
{
	NSMutableData *buffers;
	NSTimeInterval lastModified; // since 1970
}

- (NSData *) buffers;
- (unsigned long long) length;
- (NSTimeInterval) lastModified;
- (void) addData: (NSData *) data;
- (void) setLastModified: (NSTimeInterval) t;
- (void) setLength: (unsigned long long) length;

@end
#endif /* __LUCENE_STORE_RAM_FILE__ */
