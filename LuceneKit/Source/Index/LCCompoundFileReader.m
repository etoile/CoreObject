#include "LCCompoundFileReader.h"
#include "GNUstep.h"

/**
* Class for accessing a compound stream.
 * This class implements a directory, but is limited to only read operations.
 * Directory methods that would normally modify data throw an exception.
 *
 * @author Dmitry Serebrennikov
 * @version $Id$
 */
@interface LCFileEntry: NSObject
{
	long long offset;
	long long length;
}
- (long long) offset;
- (long long) length;
- (void) setOffset: (long long) o;
- (void) setLength: (long long) l;

@end

@implementation LCFileEntry
- (id) init
{
	self = [super init];
	offset = 0;
	length = 0;
	return self;
}

- (long long) offset { return offset; }
- (long long) length { return length; }
- (void) setOffset: (long long) o { offset = o; }
- (void) setLength: (long long) l { length = l; }
@end

/** Implementation of an IndexInput that reads from a portion of the
*  compound file. The visibility is left as "package" *only* because
*  this helps with testing since JUnit test cases in a different class
*  can then access package fields of this class.
*/
@implementation LCCSIndexInput

- (id) initWithCompoundFileReader: (LCCompoundFileReader *) cr
					   indexInput: (LCIndexInput *) b offset: (long long) f
						   length: (long long) len
{
	self = [self init];
	ASSIGN(reader, cr);
	ASSIGNCOPY(base, b);//FIXME: Verify
	fileOffset = f;
	length = len;
	filePointer = 0;
	return self;
}

- (void) dealloc
{
	DESTROY(reader);
	DESTROY(base);
	[super dealloc];
}

- (char) readByte
{
	char *dataBytes = NULL;
	NSMutableData *data = [[NSMutableData alloc] init];
	[self readBytes: data offset: 0 length: 1];
	AUTORELEASE(data);
	dataBytes=(char *)[data bytes];
	NSAssert1(dataBytes,@"No dataBytes: %@",[reader name]);
	return *dataBytes;
}

- (void) readBytes: (NSMutableData *) b
			offset: (int) offset
			length: (int) len
{
	long long start = [self offsetInFile];
	if (start + len > length)
    {
		len = length - start;
    }
	[base seekToFileOffset: fileOffset + start];
	[base readBytes: b offset: offset length: len];
	filePointer += len;
}

/** Expert: implements seek.  Sets current position in this file, where
*  the next {@link #readInternal(byte[],int,int)} will occur.
* @see #readInternal(byte[],int,int)
*/
- (void) seekToFileOffset: (unsigned long long) pos 
{
	long long p = (pos < length) ? pos : length;
	filePointer = p;
}

/** Closes the stream to further operations. */
- (void) close {}

- (unsigned long long) length { return length; }

- (unsigned long long) offsetInFile { return filePointer; }

- (id) copyWithZone: (NSZone *) zone
{
	// Access the same file
	LCCSIndexInput *clone = [[LCCSIndexInput allocWithZone: zone] initWithCompoundFileReader: reader
																				  indexInput: AUTORELEASE([base copy]) offset: fileOffset
																					  length: length];
        //FIXME: Why doing a [copy ] f we also copy in init
	[clone seekToFileOffset: filePointer];
	return clone;
}

@end

@implementation LCCompoundFileReader

- (id) init
{
	self = [super init];
	entries = [[NSMutableDictionary alloc] init];
	directory = nil;
	fileName = nil;
	stream = nil;
	return self;
}

- (id) initWithDirectory: (id <LCDirectory>) dir
					name: (NSString *) name
{
	self = [self init];
	ASSIGN(directory, dir);
	ASSIGNCOPY(fileName, name);
	
	BOOL success = NO;
	ASSIGN(stream, [dir openInput: name]);
	
	// read the directory and init files
	int count = [stream readVInt];
	LCFileEntry *entry = nil;
	int i;
	long prevOffset = 0;
	NSString *iden, *prevIden = nil;
	for (i=0; i<count; i++) {
		long offset = [stream readLong];
		iden = [stream readString];
		
#if 1
		if (i > 0)
			[(LCFileEntry *)[entries objectForKey: prevIden] setLength: offset - prevOffset];
#else
		if (entry != nil) {
			// set length of the previous entry
			[entry setLength: offset - [entry offset]];
		}
#endif
		
		entry = [[LCFileEntry alloc] init];
		[entry setOffset: offset];
		[entries setObject: entry forKey: iden];
		ASSIGNCOPY(prevIden, iden);
		prevOffset = offset;
		DESTROY(entry);
	}
	
#if 1
	if ((count > 0) && (prevIden != nil))
		[(LCFileEntry *)[entries objectForKey: prevIden] setLength: [stream length] - prevOffset];
#else
	// set the length of the final entry
	if (entry != nil) {
		[entry setLength: [stream length] - [entry offset]];
	}
#endif
	DESTROY(prevIden);
	
	success = YES;
	
	if (! success && (stream != nil)) {
		[stream close];
		DESTROY(stream);
	}
	
	return self;
}

- (void) dealloc
{
	DESTROY(entries);
	DESTROY(directory);
	DESTROY(fileName);
	DESTROY(stream);
	[super dealloc];
}

- (id <LCDirectory>) directory { return directory; }

- (NSString *) name { return fileName; }

- (void) close
{
	if (stream == nil)
	{
		NSLog(@"Already closed");
		return;
	}
	
	[entries removeAllObjects];
	[stream close];
	DESTROY(stream);
}

- (LCIndexInput *) openInput: (NSString *) iden
{
	if (stream == nil)
	{
		NSLog(@"Stream closed");
		return nil;
	}
	
	LCFileEntry *entry = (LCFileEntry *)[entries objectForKey: iden];
	if (entry == nil)
	{
		NSLog(@"No sub-file with iden %@ found", iden);
		return nil;
	}
    return AUTORELEASE([[LCCSIndexInput alloc] 
        initWithCompoundFileReader: self
						indexInput: stream offset: [entry offset]
							length: [entry length]]);
}

/** Returns an array of strings, one for each file in the directory. */
- (NSArray *) fileList
{
    return [entries allKeys];
}

/** Returns true iff a file with the given name exists. */
- (BOOL) fileExists: (NSString *) name
{
	return ([entries objectForKey: name]) ? YES : NO;
}

/** Returns the time the named file was last modified. */
- (NSTimeInterval) fileModified: (NSString *) name
{
	// Ignore name
	return [directory fileModified: fileName];
}

/** Set the modified time of an existing file to now. */
- (void) touchFile: (NSString *) name
{
	[directory touchFile: fileName];
}

/** Not implemented
* @throws UnsupportedOperationException */
- (BOOL) deleteFile: (NSString *) name
{
	NSLog(@"Not support");
	return NO;
}

/** Not implemented
* @throws UnsupportedOperationException */
- (void) renameFile: (NSString *) from
                 to: (NSString *) to
{
	NSLog(@"Not support");
}

/** Returns the length of a file in the directory.
* @throws IOException if the file does not exist */
- (unsigned long long) fileLength: (NSString *) name
{
	LCFileEntry *e = (LCFileEntry *) [entries objectForKey: name];
	if (e == nil)
	{
		NSLog(@"File %@ does not exist", name);
		return 0;
	}
	return [e length];
}

/** Not implemented
* @throws UnsupportedOperationException */
- (LCIndexOutput *) createOutput: (NSString *) name
{
	NSLog(@"Not support");
	return nil;
}

/** Not implemented
* @throws UnsupportedOperationException */
#if 0
public Lock makeLock(String name)
{
	throw new UnsupportedOperationException();
}
#endif
@end
