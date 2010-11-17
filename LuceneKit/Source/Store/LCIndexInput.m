#include "LCIndexInput.h"
#include "GNUstep.h"

/** Abstract base class for input from a file in a {@link Directory}.  A
* random-access input stream.  Used for all Lucene index input operations.
* @see Directory
*/

@implementation LCIndexInput

/** Reads and returns a single byte.
* @see IndexOutput#writeByte(byte)
*/
- (char) readByte
{
	return 0;
}

/** Reads a specified number of bytes into an array at the specified offset.
* @param b the array to read bytes into
* @param offset the offset in the array to start storing bytes
* @param len the number of bytes to read
* @see IndexOutput#writeBytes(byte[],int)
*/
- (void) readBytes: (NSMutableData *) b offset: (int) offset length: (int) len;
{
}

/** Reads four bytes and returns an int.
* @see IndexOutput#writeInt(int)
*/
- (long) readInt
{
	return (([self readByte] & 0xFF) << 24) | (([self readByte] & 0xFF) << 16)
	| (([self readByte] & 0xFF) <<  8) | ([self readByte] & 0xFF);
}

/** Reads an int stored in variable-length format.  Reads between one and
* five bytes.  Smaller values take fewer bytes.  Negative numbers are not
* supported.
* @see IndexOutput#writeVInt(int)
*/
- (long) readVInt
{
	char b = [self readByte];
	int shift; 
	long i = b & 0x7F;
	for (shift = 7; (b & 0x80) != 0; shift += 7) 
    {
		b = [self readByte];
		i |= (b & 0x7F) << shift;
    }
	return i;
}

/** Reads eight bytes and returns a long.
* @see IndexOutput#writeLong(long)
*/
- (long long) readLong
{
	return (((long long)[self readInt]) << 32) | 
	((long long)[self readInt] & 0xFFFFFFFFL);
}

/** Reads a long stored in variable-length format.  Reads between one and
* nine bytes.  Smaller values take fewer bytes.  Negative numbers are not
* supported. */
- (long long) readVLong
{
	char b = [self readByte];
	long long i = b & 0x7F;
	int shift;
	for (shift = 7; (b & 0x80) != 0; shift += 7) 
    {
		b = [self readByte];
		i |= (b & 0x7FL) << shift;
    }
	return i;
}

/** Reads a string.
* @see IndexOutput#writeString(String)
*/
- (NSString *) readString
{
	int length = [self readVInt];
	
	//if (chars == nil || length > sizeof(chars))
	NSMutableString *s = [[NSMutableString alloc] init];
	[self readChars: s start: 0 length: length];
	return AUTORELEASE(s);
	
}

/** Reads UTF-8 encoded characters into an array.
* @param buffer the array to read characters into
* @param start the offset in the array to start storing characters
* @param length the number of characters to read
* @see IndexOutput#writeChars(String,int,int)
*/
- (void) readChars: (NSMutableString *) s 
			 start: (int) start length: (int) length
{
    int i;
    unichar *buffer = malloc(sizeof(unichar)*length);
    for (i = 0; i < length; i++) {
		unichar b = [self readByte];
		if ((b & 0x80) == 0)
			buffer[i] = (unichar)(b & 0x7F);
		else if ((b & 0xE0) != 0xE0) {
			buffer[i] = (unichar)(((b & 0x1F) << 6)
								  | ([self readByte] & 0x3F));
		} else
			buffer[i] = (unichar)(((b & 0x0F) << 12)
								  | (([self readByte] & 0x3F) << 6)
								  |  ([self readByte] & 0x3F));
    }
    NSString *s1, *s2;
    int end = [s length];
    if (start > end)
	{
        s1 = [s substringToIndex: end];
	}
    else
	{
        s1 = [s substringToIndex: start];
	}
	//    NSRange r = NSMakeRange(start, length);
    s2 = [NSString stringWithCharacters: buffer length: length];
    [s setString: [NSString stringWithFormat: @"%@%@", s1, s2]];
    free(buffer);
    buffer = NULL;
}

/** Closes the stream to futher operations. */
- (void) close
{
}

/** Returns the current position in this file, where the next read will
* occur.
* @see #seek(long)
*/
- (unsigned long long) offsetInFile
{
	return -1;
}

/** Sets current position in this file, where the next read will occur.
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

/** Returns a clone of this stream.
*
* <p>Clones of a stream access the same data, and are positioned at the same
* point as the stream they were cloned from.
*
* <p>Expert: Subclasses must ensure that clones may be positioned at
* different points in the input from each other and from the stream they
* were cloned from.
*/
- (id) copyWithZone: (NSZone *) zone
{
	return [super copy];
}

@end
