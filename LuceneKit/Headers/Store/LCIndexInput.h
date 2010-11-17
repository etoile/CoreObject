#ifndef __LUCENE_STORE_INDEX_INPUT__
#define __LUCENE_STORE_INDEX_INPUT__

#include <Foundation/Foundation.h>

/** Read a file content */
@interface LCIndexInput: NSObject <NSCopying>
{
}

/** Read a four-bytes Int */
- (long) readInt;
/** Read a four-byte VInt */
- (long) readVInt;
/** Read a eight-byte Long */
- (long long) readLong;
/** Read a eight-byte VLong */
- (long long) readVLong;
/** Read a string */
- (NSString *) readString;
/** Read string into buffer */
- (void) readChars: (NSMutableString *) buffer 
             start: (int) start 
			length: (int) length;

/** <override-subclass /> Read a byte */
- (char) readByte;
/** <override-subclass /> Read bytes, start at offset in b */
- (void) readBytes: (NSMutableData *) b 
            offset: (int) offset 
			length: (int) len;
/** <override-subclass /> Close file */
- (void) close;
/** <override-subclass /> Offset in file */
- (unsigned long long) offsetInFile; // filePointer
/** <override-subclass /> Seek to offset in file */
- (void) seekToFileOffset: (unsigned long long) pos;  // -seek:
/** <override-subclass /> Length of file */
- (unsigned long long) length;

@end

#endif /* __LUCENE_STORE_INDEX_INPUT__ */
