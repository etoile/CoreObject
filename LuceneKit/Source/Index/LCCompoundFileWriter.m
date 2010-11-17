#include "LCCompoundFileWriter.h"
#include "LCIndexOutput.h"
#include "GNUstep.h"

/**
* Combines multiple files into a single compound file.
 * The file format:<br>
 * <ul>
 *     <li>VInt fileCount</li>
 *     <li>{Directory}
 *         fileCount entries with the following structure:</li>
 *         <ul>
 *             <li>long dataOffset</li>
 *             <li>UTFString extension</li>
 *         </ul>
 *     <li>{File Data}
 *         fileCount entries with the raw data of the corresponding file</li>
 * </ul>
 *
 * The fileCount integer indicates how many files are contained in this compound
 * file. The {directory} that follows has that many entries. Each directory entry
 * contains an encoding identifier, a long pointer to the start of this file's
 * data section, and a UTF String with that file's extension.
 *
 * @author Dmitry Serebrennikov
 * @version $Id$
 */
@interface LCWriterFileEntry: NSObject
{
	/** source file */
	NSString *file;
	/** temporary holder for the start of directory entry for this file */
	long long directoryOffset;
	/** temporary holder for the start of this file's data section */
	long long dataOffset;
}
- (NSString *) file;
- (long long) directoryOffset;
- (long long) dataOffset;
- (void) setFile: (NSString *) f;
- (void) setDirectoryOffset: (long long) f;
- (void) setDataOffset: (long long) f;
@end

@implementation LCWriterFileEntry

- (void) dealloc
{
	DESTROY(file);
	[super dealloc];
}

- (NSString *) file { return file; }
- (long long) directoryOffset { return directoryOffset; }
- (long long) dataOffset { return dataOffset; }
- (void) setFile: (NSString *) f { ASSIGN(file, f); }
- (void) setDirectoryOffset: (long long) f { directoryOffset = f; }
- (void) setDataOffset: (long long) f { dataOffset = f; }

@end

@interface LCCompoundFileWriter (LCPrivate)
- (void) copyFile: (LCWriterFileEntry *) source
      indexOutput: (LCIndexOutput *) os
             data: (NSMutableData *) buffer;

@end

@implementation LCCompoundFileWriter
- (id) init
{
	self = [super init];
	merged = NO;
	return self;
}

/** Create the compound stream in the specified file. The file name is the
*  entire name (no extensions are added).
*  @throws NullPointerException if <code>dir</code> or <code>name</code> is null
*/
- (id) initWithDirectory: (id <LCDirectory>) dir name: (NSString *) name
{
	if (dir == nil)
	{
		NSLog(@"directory cannot be null");
	    return nil;
	}
	if (name == nil)
	{
		NSLog(@"name cannot be null");
	    return nil;
	}
	
	self = [self init];
	ASSIGN(directory, dir);
	ASSIGN(fileName, name);
	ids = [[NSMutableSet alloc] init];
	entries = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(directory);
	DESTROY(fileName);
	DESTROY(ids);
	DESTROY(entries);
	[super dealloc];
}

/** Returns the directory of the compound file. */
- (id <LCDirectory>) directory
{
	return directory;
}

/** Returns the name of the compound file. */
- (NSString *) name
{
	return fileName;
}

/** Add a source stream. <code>file</code> is the string by which the 
*  sub-stream will be known in the compound stream.
* 
*  @throws IllegalStateException if this writer is closed
*  @throws NullPointerException if <code>file</code> is null
*  @throws IllegalArgumentException if a file with the same name
*   has been added already
*/
- (void) addFile: (NSString *) file
{
	if (merged)
	{
		NSLog(@"Can't add extensions after merge has been called");
		return;
	}
	
	if (file == nil)
	{
		NSLog(@"file cannot be null");
		return;
	}
	
	if ([ids containsObject: file])
	{
		NSLog(@"File %@ already added", file);
		return;
	}
	
	LCWriterFileEntry *entry = [[LCWriterFileEntry alloc] init];
	[entry setFile: file];
	[entries addObject: entry];
	[ids addObject: file];
	DESTROY(entry);
}

/** Merge files with the extensions added up to now.
*  All files with these extensions are combined sequentially into the
*  compound stream. After successful merge, the source files
*  are deleted.
*  @throws IllegalStateException if close() had been called before or
*   if no file has been added to this object
*/
- (void) close
{
	if (merged)
	{
		NSLog(@"Merge already performed");
		return;
	}
	
	if ([entries count] == 0)
	{
		NSLog(@"No entries to merge have been defined");
		return;
	}
	
	merged = YES;
	
	// open the compound stream
	LCIndexOutput *os = nil;
	os = [directory createOutput: fileName];
	
	// Write the number of entries
	[os writeVInt: [entries count]];
	
	// Write the directory with all offsets at 0.
	// Remember the positions of directory entries so that we can
	// adjust the offsets later
	NSEnumerator *e = [entries objectEnumerator];
	LCWriterFileEntry *fe;
	while ((fe = [e nextObject]))
	{
		[fe setDirectoryOffset: [os offsetInFile]];
		[os writeLong: 0];    // for now
		[os writeString: [fe file]];
	}
	
	// Open the files and copy their data into the stream.
	// Remember the locations of each file's data section.
	NSMutableData *buffer;
	e = [entries objectEnumerator];
	while ((fe = [e nextObject]))
	{
		buffer = [[NSMutableData alloc] init];
		[fe setDataOffset: [os offsetInFile]];
		[self copyFile: fe indexOutput: os data: buffer];
		DESTROY(buffer);
	}
	
	// Write the data offsets into the directory of the compound stream
	e = [entries objectEnumerator];
	while ((fe = [e nextObject]))
	{
		[os seekToFileOffset: [fe directoryOffset]];
		[os writeLong: [fe dataOffset]];
	}
	
	// Close the output stream. Set the os to null before trying to
	// close so that if an exception occurs during the close, the
	// finally clause below will not attempt to close the stream
	// the second time.
	LCIndexOutput *tmp = os;
	os = nil;
	[tmp close];
	
	if (os != nil) { [os close]; } 
}

/** Copy the contents of the file with specified extension into the
*  provided output stream. Use the provided buffer for moving data
*  to reduce memory allocation.
*/
- (void) copyFile: (LCWriterFileEntry *) source 
      indexOutput: (LCIndexOutput *) os
             data: (NSMutableData *) buffer
{
	LCIndexInput *is = nil;
	long startPtr = [os offsetInFile];
	
	is = [directory openInput: [source file]];
	long length = [is length];
	//  long remainder = length;
	//  int chunk = [buffer length];
	
	[is readBytes: buffer offset: 0 length: length];
	[os writeBytes: buffer length: length];
	
	// Verify that the output length diff is equal to original file
	long endPtr = [os offsetInFile];
	long diff = endPtr - startPtr;
	if (diff != length)
	{
		NSLog(@"Difference in the output file offsets %ld does not match the original file length %ld", diff, length);
		return;
	}
	
	if (is != nil) [is close];
}
@end
