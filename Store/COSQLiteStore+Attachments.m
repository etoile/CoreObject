/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  April 2013
    License:  MIT  (see COPYING)
 */

#import "COSQLiteStore.h"
#import "COSQLiteStore+Attachments.h"

#ifdef GNUSTEP
#   include <openssl/sha.h>
#else

#   include <CommonCrypto/CommonDigest.h>

#   define SHA_CTX CC_SHA1_CTX
#   define SHA_DIGEST_LENGTH CC_SHA1_DIGEST_LENGTH
#   define SHA1_Init CC_SHA1_Init
#   define SHA1_Update CC_SHA1_Update
#   define SHA1_Final CC_SHA1_Final
#   define SHA1 CC_SHA1
#endif

@implementation COSQLiteStore (Attachments)

- (NSURL *)attachmentsURL
{
#ifdef GNUSTEP
    return [url_ URLByAppendingPathComponent: @"attachments/"];
#else
    return [url_ URLByAppendingPathComponent: @"attachments" isDirectory: YES];
#endif
}

static NSData *hashItemAtURL(NSURL *aURL)
{
    SHA_CTX shactx;
    if (1 != SHA1_Init(&shactx))
    {
        return nil;
    }

#ifdef GNUSTEP
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath: aURL.path];
#else
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL: aURL
                                                           error: NULL];
#endif

    int fd = fh.fileDescriptor;

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

static NSData *hashItemWithData(NSData *data)
{
    unsigned char digest[SHA_DIGEST_LENGTH];

    if (SHA1(data.bytes, data.length, digest) == NULL)
    {
        return nil;
    }
    return [NSData dataWithBytes: digest length: SHA_DIGEST_LENGTH];
}

static NSString *hexString(NSData *aData)
{
    const NSUInteger len = aData.length;
    if (0 == len)
    {
        return @"";
    }
    const unsigned char *bytes = (const unsigned char *)aData.bytes;

    NSMutableString *result = [NSMutableString stringWithCapacity: len * 2];
    for (NSUInteger i = 0; i < len; i++)
    {
        [result appendFormat: @"%02x", (int)bytes[i]];
    }
    return result;
}

static NSData *dataFromHexString(NSString *hexString)
{
    NSMutableData *result = [NSMutableData dataWithCapacity: hexString.length / 2];
    const char *cstring = hexString.UTF8String;

    unsigned byteAsInt;
    while (1 == sscanf(cstring, "%2x", &byteAsInt))
    {
        unsigned char byte = byteAsInt;
        [result appendBytes: &byte length: 1];
        cstring += 2;
    }

    return result;
}

- (NSURL *)URLForAttachmentID: (COAttachmentID *)aHash
{
    NSData *data = aHash.dataValue;

    NSParameterAssert([data length] == SHA_DIGEST_LENGTH);
    return [[[self attachmentsURL] URLByAppendingPathComponent: hexString(data)]
        URLByAppendingPathExtension: @"attachment"];
}

- (COAttachmentID *)importAttachmentFromURL: (NSURL *)aURL
{
    NILARG_EXCEPTION_TEST(aURL)
    return [self importAttachmentFromData: nil orURL: aURL];
}

- (COAttachmentID *)importAttachmentFromData: (NSData *)data
{
    NILARG_EXCEPTION_TEST(data);
    return [self importAttachmentFromData: data orURL: nil];
}

- (COAttachmentID *)importAttachmentFromData: (NSData *)data orURL: (NSURL *)sourceURL
{
    NSFileManager *fm = [NSFileManager defaultManager];

    [fm createDirectoryAtURL: [self attachmentsURL]
 withIntermediateDirectories: NO
                  attributes: nil
                       error: NULL];

    NSData *hash = (sourceURL == nil ? hashItemWithData(data) : hashItemAtURL(sourceURL));
    COAttachmentID *attachmentID = [[COAttachmentID alloc] initWithData: hash];
    NSURL *attachmentURL = [self URLForAttachmentID: attachmentID];

    if ([fm fileExistsAtPath: attachmentURL.path])
        return attachmentID;

    NSError *error = nil;

    if (sourceURL == nil)
    {
        if (![data writeToURL: attachmentURL options: NSDataWritingAtomic error: &error])
        {
            // This is a real error, e.g. disk full, store not writable, filesystem not available, etc.
            return nil;
        }
    }
    else
    {
        if (![fm copyItemAtURL: sourceURL toURL: attachmentURL error: &error])
        {
            // This is a real error, e.g. disk full, store not writable, filesystem not available, etc.
            return nil;
        }
    }

    return attachmentID;
}

- (NSArray *)attachments
{
    NSMutableArray *result = [NSMutableArray array];
    NSString *path = [self attachmentsURL].path;

    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
    {
        return result;
    }

    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: path error: &error];
    // TODO: Implement some recovery strategy and error reporting
    assert(files != nil && error == nil);

    for (NSString *file in files)
    {
        NSString *attachmentHexString = file.stringByDeletingPathExtension;
        NSData *hash = dataFromHexString(attachmentHexString);
        [result addObject: [[COAttachmentID alloc] initWithData: hash]];
    }
    return result;
}

- (BOOL)deleteAttachment: (COAttachmentID *)hash
{
    return [[NSFileManager defaultManager] removeItemAtPath: [self URLForAttachmentID: hash].path
                                                      error: NULL];
}

@end
