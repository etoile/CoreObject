/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "COItem.h"

@interface COItem (Binary)

@property (nonatomic, readonly) NSData *dataValue;

- (instancetype)initWithData: (NSData *)aData;

@end
