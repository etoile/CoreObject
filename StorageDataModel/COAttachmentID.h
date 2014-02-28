/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

/**
 * @group Storage Data Model
 * @abstract 
 * Reference to an attachment, composed of the hash of the referenced attachment.
 *
 * Can appear as a value object inside a COItem.
 */
@interface COAttachmentID : NSObject <NSCopying>
{
	NSData *_data;
}

/**
 * Initializes and returns an attachmend ID based on the given hash.
 *
 * You should almost always use -[COSSQLiteStore importAttachmentFromURL:] 
 * to get an attachment ID, and let the store import the original attachment.
 *
 * The hash represents the attachment in a unique way. For example, you can 
 * pass a hash generated from the attachment content.
 */
- (instancetype) initWithData: (NSData *)aData;
/**
 * Returns the attachment hash.
 *
 * See -initWithData:.
 */
- (NSData *) dataValue;

@end
