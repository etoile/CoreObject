#import <Foundation/Foundation.h>

@interface COSQLiteStore (Attachments)

- (NSURL *) URLForAttachmentID: (NSData *)aHash;
- (NSData *) importAttachmentFromURL: (NSURL *)aURL;

@end
