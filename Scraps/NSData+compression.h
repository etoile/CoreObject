/*
    Copyright (C) 2010 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  July 2010
    License:  MIT  (see COPYING)
 */

#import <Foundation/NSData.h>

@interface NSData (Compression)

- (NSData *)zlibCompressed;
- (NSData *)zlibDecompressed;

@end
