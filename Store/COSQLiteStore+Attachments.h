/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  April 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

NS_ASSUME_NONNULL_BEGIN

@interface COSQLiteStore (Attachments)

- (nullable NSURL *)URLForAttachmentID: (COAttachmentID *)aHash;
- (nullable COAttachmentID *)importAttachmentFromURL: (NSURL *)aURL;
- (nullable COAttachmentID *)importAttachmentFromData: (NSData *)data;

@end

NS_ASSUME_NONNULL_END
