#import "NSFileManager+TempFile.h"
#include "glibc_hack_unistd.h"
#include <string.h>
#if defined(__sun)
/* For mkdtemp on Solaris versions older than Solaris Express 4/06 */
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>

char *mkdtemp(char *pattern)
{
	if (!mktemp(pattern) || mkdir(pattern, 0700))
	{
		return NULL;
	}
	return pattern;
}
#endif

static char * makeTempPattern(void)
{
	NSString * patternString = NSTemporaryDirectory();
	patternString = 
		[patternString stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]];
	// Make sure that this application's temporary directory exists.
	[[NSFileManager defaultManager] createDirectoryAtPath: patternString 
	                                           attributes: nil];
	patternString = [patternString stringByAppendingPathComponent:@"tmpXXXXXXXX"];
	return strdup([patternString UTF8String]);
}

@implementation NSFileManager (TempFile)
- (NSFileHandle*) tempFile
{
	char * pattern = makeTempPattern();
	int fd = mkstemp(pattern);
	free(pattern);
	return [[[NSFileHandle alloc] initWithFileDescriptor:fd] autorelease];
}
- (NSString*) tempDirectory
{
	char * pattern = makeTempPattern();
	NSString * dirName = nil;
	if (NULL != mkdtemp(pattern))
	{
		dirName = [NSString stringWithUTF8String:pattern];
		free(pattern);
	}
	return dirName;
}
@end
