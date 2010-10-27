/* =============================================================================
    PROJECT:    Filie
    FILE:       NSFileManager+NameForTempFile.m
    
    PURPOSE:    Assorted unique-filename-generation methods.
    
    COPYRIGHT:  (c) 2004 by M. Uli Kusterer, all rights reserved.
    
    AUTHORS:    M. Uli Kusterer - UK
    
    LICENSES:   GNU GPL, Modified BSD
    
    REVISIONS:
        2004-02-08  UK  Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import "NSFileManager+NameForTempFile.h"


@implementation NSFileManager (UKNameForTempFile)

// -----------------------------------------------------------------------------
//	nameForTempFile:
//		Quickly generates a (pretty random) unique file name for a file in the
//		NSTemporaryDirectory and returns that path. Use this for temporary
//		files the user will not see.
//
//	REVISIONS:
//		2004-03-21	witness	Documented.
// -----------------------------------------------------------------------------

-(NSString*)	nameForTempFile
{
	NSString*   tempDir = NSTemporaryDirectory();
	int			n = rand();
	NSString*   fname = nil;
	
	if( !tempDir )
		return nil;
	while( !fname || [self fileExistsAtPath: fname] )
		fname = [tempDir stringByAppendingPathComponent: [NSString stringWithFormat:@"temp_%i", n++]];
	
	return fname;
}

// -----------------------------------------------------------------------------
//	uniqueFileName:
//		Takes a file path and if an item already exists at that path, generates
//		a unique file name by appending a number. Use this to e.g. add files
//		to user-owned folders (like the desktop) to ensure you don't overwrite
//		any valuable data.
//
//      May return NIL if it's searched for a while (after about 2 billion
//      attempts).
//
//	REVISIONS:
//		2004-03-21	witness	Documented.
// -----------------------------------------------------------------------------

-(NSString*)	uniqueFileName: (NSString*)oldName
{
	NSString*   baseName = [oldName stringByDeletingPathExtension];
	NSString*   suffix = [oldName pathExtension];
	int			n = 1;
	NSString*   fname = oldName;
	
	while( [self fileExistsAtPath: fname] ) // Keep looping until we have a unique name:
	{
		if( [suffix length] == 0 )  // Build "/folder/file 1"-style path:
			fname = [baseName stringByAppendingString: [NSString stringWithFormat:@" %i", n++]];
		else						// Build "/folder/file 1.suffix"-style path:
			fname = [baseName stringByAppendingString: [NSString stringWithFormat:@" %i.%@", n++, suffix]];
		
		if( n <= 0 )	// overflow!
			return nil;
	}
	
	return fname;
}

@end
