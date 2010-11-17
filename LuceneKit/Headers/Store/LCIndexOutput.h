#ifndef __LUCENE_STORE_INDEX_OUTPUT__
#define __LUCENE_STORE_INDEX_OUTPUT__

#include <Foundation/Foundation.h>

/** Write to a file */
@interface LCIndexOutput: NSObject

/** Write a four-byte Int */
- (void) writeInt: (long) i;
/** Write a four-byte VInt */
- (void) writeVInt: (long) i;
/** Write a eight-byte Long */
- (void) writeLong: (long long) i;
/** Write a eight-byte VLong */
- (void) writeVLong: (long long) i;
/** Write a string */
- (void) writeString: (NSString *) s;
/** Write a string */
- (void) writeChars: (NSString *) s start: (int) start length: (int) length;
/** <override-subclass /> Write a byte */
- (void) writeByte: (char) b;
/** <override-subclass /> Write bytes with len */
- (void) writeBytes: (NSData *)b length: (int) len;
/** <override-subclass /> flush data in memory */
- (void) flush;
/** <override-subclass /> Close file */
- (void) close;
/** <override-subclass /> Offset in file */
- (unsigned long long) offsetInFile;
/** <override-subclass /> Seek to offset in file */
- (void) seekToFileOffset: (unsigned long long) pos;
/** <override-subclass /> File length */
- (unsigned long long) length;

@end

#endif /* __LUCENE_STORE_INDEX_OUTPUT__ */
