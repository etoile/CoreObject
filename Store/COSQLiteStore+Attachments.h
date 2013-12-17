/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  April 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COSQLiteStore (Attachments)

- (NSURL *) URLForAttachmentID: (COAttachmentID *)aHash;
- (COAttachmentID *) importAttachmentFromURL: (NSURL *)aURL;

@end
