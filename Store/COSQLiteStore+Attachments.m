#import "COSQLiteStore.h"
#import "COSQLiteStore+Attachments.h"
#include <openssl/sha.h>

@implementation COSQLiteStore (Attachments)

- (NSURL *) attachmentsURL
{
    return [url_ URLByAppendingPathComponent: @"attachments" isDirectory: YES];
}

static NSData *hashItemAtURL(NSURL *aURL)
{
    SHA_CTX shactx;
    if (1 != SHA1_Init(&shactx))
    {
        return nil;
    }
    
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL: aURL
                                                           error: NULL];
    
    int fd = [fh fileDescriptor];
    
    unsigned char buf[4096];
    
    while (1)
    {
        ssize_t bytesread = read(fd, buf, sizeof(buf));
        
        if (bytesread == 0)
        {
            [fh closeFile];
            break;
        }
        if (bytesread < 0)
        {
            [fh closeFile];
            return nil;
        }
        if (1 != SHA1_Update(&shactx, buf, bytesread))
        {
            [fh closeFile];
            return nil;
        }
    }
    
    unsigned char digest[SHA_DIGEST_LENGTH];
    if (1 != SHA1_Final(digest, &shactx))
    {
        return nil;
    }
    return [NSData dataWithBytes: digest length: SHA_DIGEST_LENGTH];
}

static NSString *hexString(NSData *aData)
{
    const NSUInteger len = [aData length];
    if (0 == len)
    {
        return @"";
    }
    const unsigned char *bytes = (const unsigned char *)[aData bytes];
    
    NSMutableString *result = [NSMutableString stringWithCapacity: len * 2];
    for (NSUInteger i = 0; i < len; i++)
    {
        [result appendFormat:@"%02x", (int)bytes[i]];
    }
    return result;
}

static NSData *dataFromHexString(NSString *hexString)
{
    NSMutableData *result = [NSMutableData dataWithCapacity: [hexString length] / 2];
    const char *cstring = [hexString UTF8String];
    
    unsigned byteAsInt;
    while (1 == sscanf(cstring, "%2x", &byteAsInt))
    {
        unsigned char byte = byteAsInt;
        [result appendBytes: &byte length: 1];
        cstring += 2;
    }
    
    return result;
}

- (NSURL *) URLForAttachmentID: (NSData *)aHash
{
    NSParameterAssert([aHash length] == SHA_DIGEST_LENGTH);
    return [[[self attachmentsURL] URLByAppendingPathComponent: hexString(aHash)]
            URLByAppendingPathExtension: @"attachment"];
}

- (NSData *) importAttachmentFromURL: (NSURL *)aURL
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm createDirectoryAtURL: [self attachmentsURL]
      withIntermediateDirectories: NO
                       attributes: nil
                            error: NULL])
    {
        return nil;
    }
    
    // Hash it
    
    NSData *hash = hashItemAtURL(aURL);
    NSURL *attachmentURL = [self URLForAttachmentID: hash];
    
    if (![fm fileExistsAtPath: [attachmentURL path]])
    {
        if (NO == [fm copyItemAtURL: aURL toURL: attachmentURL error: NULL])
        {
            return nil;
        }
    }
    
    return hash;
}

- (NSArray *) attachments
{
    NSMutableArray *result = [NSMutableArray array];
    NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath: [[self attachmentsURL] path]];
    for (NSString *file in files)
    {
        NSString *attachmentHexString = [file stringByDeletingPathExtension];
        NSData *hash = dataFromHexString(attachmentHexString);
        [result addObject: hash];
    }
    return result;
}

- (BOOL) deleteAttachment: (NSData *)hash
{
    NSParameterAssert([hash length] == SHA_DIGEST_LENGTH);
    return [[NSFileManager defaultManager] removeItemAtPath: [[self URLForAttachmentID: hash] path]
                                                      error: NULL];
}

@end
