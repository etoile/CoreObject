#ifndef __LUCENE_STORE_DIRECTORY__
#define __LUCENE_STORE_DIRECTORY__

#include <Foundation/Foundation.h>
#include "LCIndexInput.h"
#include "LCIndexOutput.h"

/** A Directory is a flat list of files.  Files may be written once, when they
* are created.  Once a file is created it may only be opened for read, or
* deleted.  Random access is permitted both when reading and writing.
*
* <p> Java's i/o APIs not used directly, but rather all i/o is
* through this API.  This permits things such as: <ul>
* <li> implementation of RAM-based indices;
* <li> implementation indices stored in a database, via JDBC;
* <li> implementation of an index as a single file;
* </ul>
*
* @author Doug Cutting
*/

@protocol LCDirectory <NSObject>

/** Returns an array of strings, one for each file in the directory. */
- (NSArray *) fileList;

	/** Returns true iff a file with the given name exists. */
- (BOOL) fileExists: (NSString *) absolutePath;

	/** Returns the time the named file was last modified. */
- (NSTimeInterval) fileModified: (NSString *) absolutePath;

	/** Set the modified time of an existing file to now. */
- (void) touchFile: (NSString *) absolutePath;

	/** Removes an existing file in the directory. */
- (BOOL) deleteFile: (NSString *) absolutePath;

	/** Renames an existing file in the directory.
    If a file already exists with the new name, then it is replaced.
    This replacement should be atomic. */
- (void) renameFile: (NSString *) oldPath to: (NSString *) newPath;

	/** Returns the length of a file in the directory. */
- (unsigned long long) fileLength: (NSString *) absolutePath;

/** Creates a new, empty file in the directory with the given name.
Returns a stream writing this file. */
- (LCIndexOutput *) createOutput: (NSString *) name;


/** Returns a stream reading an existing file. */
- (LCIndexInput *) openInput: (NSString *) name;


#if 0 // FIXME: don't know how to do that
/** Construct a {@link Lock}.
* @param name the name of the lock file
*/
- (LCLock *) makeLick: (NSString *) absolutePath;
#endif

	/** Closes the store. */
- (void) close;

@end

#endif /* __LUCENE_STORE_DIRECTORY__ */
