#include "LCIndexOutput.h"

/** Abstract base class for output to a file in a Directory.  A random-access
* output stream.  Used for all Lucene index output operations.
* @see Directory
* @see IndexInput
*/
@implementation LCIndexOutput

/** Writes a single byte.
* @see IndexInput#readByte()
*/
- (void) writeByte: (char) b
{
}

/** Writes an array of bytes.
* @param b the bytes to write
* @param length the number of bytes to write
* @see IndexInput#readBytes(byte[],int,int)
*/
- (void) writeBytes: (NSData *)b length: (int) len
{
}

/** Writes an int as four bytes.
* @see IndexInput#readInt()
*/
- (void) writeInt: (long) i
{
	[self writeByte: (char)(i >> 24)];
	[self writeByte: (char)(i >> 16)];
	[self writeByte: (char)(i >> 8)];
	[self writeByte: (char)i];
}

/** Writes an int in a variable-length format.  Writes between one and
* five bytes.  Smaller values take fewer bytes.  Negative numbers are not
* supported.
* @see IndexInput#readVInt()
*/
- (void) writeVInt: (long) i
{
	while ((i & ~0x7F) != 0) 
    {
		[self writeByte: (char)((i & 0x7f) | 0x80)];
		i = (i >> 7) & 0x1FFFFFFL; // clean the highest 7 bits
								   // i >>>= 7;
    }
	[self writeByte: (char)i];
}

/** Writes a long as eight bytes.
* @see IndexInput#readLong()
*/
- (void) writeLong: (long long) i
{
    [self writeInt: (int) (i >> 32)];
    [self writeInt: (int) i];
}

/** Writes an long in a variable-length format.  Writes between one and five
* bytes.  Smaller values take fewer bytes.  Negative numbers are not
* supported.
* @see IndexInput#readVLong()
*/
- (void) writeVLong: (long long) i
{
	while ((i & ~0x7F) != 0) {
		[self writeByte: (char)((i & 0x7f) | 0x80)];
		i = (i >> 7) & 0x1FFFFFFFFFFFFFFLL; // clean the highest 7 bits
											// i >>>= 7;
	}
	[self writeByte: (char)i];
}

/** Writes a string.
* @see IndexInput#readString()
*/
- (void) writeString: (NSString *) s
{
	int length = [s length];
	[self writeVInt: length];
	[self writeChars: s start: 0 length: length];
}

/** Writes a sequence of UTF-8 encoded characters from a string.
* @param s the source of the characters
* @param start the first character in the sequence
* @param length the number of characters in the sequence
* @see IndexInput#readChars(char[],int,int)
*/
- (void) writeChars: (NSString *) s start: (int) start length: (int) length
{
	int i, end = start + length;
	unichar code;
	for (i = start; i < end; i++) 
    {
		code = [s characterAtIndex: i];
		if (code >= 0x01 && code <= 0x7F)
			[self writeByte: (char)code];
		else if (((code >= 0x80) && (code <= 0x7FF)) || code == 0) {
			[self writeByte: (char)(0xC0 | (code >> 6))];
			[self writeByte: (char)(0x80 | (code & 0x3F))];
		} else {
			[self writeByte: (char)(0xE0 | ((code >> 12) & 0xFFFL))];
			//[self writeByte: (char)(0xE0 | (code >>> 12))];
			[self writeByte: (char)(0x80 | ((code >> 6) & 0x3F))];
			[self writeByte: (char)(0x80 | (code & 0x3F))];
		}
    }
}

/** Forces any buffered output to be written. */
- (void) flush
{
}

/** Closes this stream to further operations. */
- (void) close
{
}

/** Returns the current position in this file, where the next write will
* occur.
* @see #seek(long)
*/
- (unsigned long long) offsetInFile
{
	return 0;
}

/** Sets current position in this file, where the next write will occur.
* @see #getFilePointer()
*/
- (void) seekToFileOffset: (unsigned long long) pos
{
}

/** The number of bytes in the file. */
- (unsigned long long) length
{
	return 0;
}

@end
