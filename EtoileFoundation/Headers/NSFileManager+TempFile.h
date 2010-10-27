#import <Foundation/Foundation.h>

/**
 * Extensions to NSFileManager for creating temporary files and directories.
 */
@interface NSFileManager (TempFile)
/**
 * Safely returns a temporary file.
 */
- (NSFileHandle*) tempFile;
/**
 * Creates a new temporary directory and returns its name.
 */
- (NSString*) tempDirectory;
@end
