/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

/**
 * @group Storage Data Model
 * @abstract
 * Reference to an attachment, composed of the hash of the referenced attachment.
 * Can appear as a value object inside a COItem.
 */
@interface COAttachmentID : NSObject
{
	NSData *_data;
}

- (instancetype) initWithData: (NSData *)aData;
- (NSData *) dataValue;

@end
