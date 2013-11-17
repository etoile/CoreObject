#import <CoreObject/CoreObject.h>

@interface COSQLiteStore (Attachments)

- (NSURL *) URLForAttachmentID: (COAttachmentID *)aHash;
- (COAttachmentID *) importAttachmentFromURL: (NSURL *)aURL;

@end
