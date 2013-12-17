/*
    Copyright (C) 2010 Eric Wasylishen

    Date:  July 2010
    License:  MIT  (see COPYING)
 */

#import <Foundation/NSData.h>

@interface NSData (Compression)

- (NSData *)zlibCompressed;
- (NSData *)zlibDecompressed;

@end
