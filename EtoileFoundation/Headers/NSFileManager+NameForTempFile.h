/* =============================================================================
    PROJECT:    Filie
    FILE:       NSFileManager+NameForTempFile.h
    
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

#import <Foundation/Foundation.h>

// WARNING: Deprecated API, update your code to use the replacement API
// NSFileManager+Etoile.

// -----------------------------------------------------------------------------
//  Categories:
// -----------------------------------------------------------------------------

@interface NSFileManager (UKNameForTempFile)

-(NSString*)	nameForTempFile;                        // "/Temporary Items/temp_73987765"
-(NSString*)	uniqueFileName: (NSString*)oldPath;     // "path/original name.txt" -> "path/original name 2.txt"

@end
