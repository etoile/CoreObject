/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "COItem.h"

@interface COItem (Binary)

- (NSData *) dataValue;
- (id) initWithData: (NSData *)aData;

@end
