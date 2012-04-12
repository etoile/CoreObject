#include <openssl/sha.h>
#import "NSData+sha1.h"
#include "stdio.h"

@implementation NSData (sha1)

- (NSData *)sha1Hash
{
	unsigned char digest[SHA_DIGEST_LENGTH];
	SHA1([self bytes], [self length], digest);
	return [NSData dataWithBytes: digest length: SHA_DIGEST_LENGTH];
}

- (NSString *)sha1HashHexString
{
	return [[self sha1Hash] hexString];
}

- (NSString *)hexString
{
	NSUInteger len = [self length];
	NSMutableString *string = [NSMutableString stringWithCapacity: 2*len];
	const unsigned char *bytes = [self bytes];
	
	for (NSUInteger i=0; i<len; i++)
	{
		[string appendFormat:@"%02x", (unsigned int)bytes[i]];
	}
	return string;
}

+ (NSData *)dataWithHexString: (NSString*)hex
{
	const NSUInteger len = [hex length];
	if (len % 2 != 0 || len == 0)
	{
		return nil;
	}
	
	NSMutableData *data = [NSMutableData dataWithLength: len/2];
	const char *hexdata = [hex UTF8String];
	unsigned char *outputbytes = [data mutableBytes];
	
	for (NSUInteger i=0; i < len; i+=2)
	{
		unsigned int byte;
		sscanf(hexdata+i, "%02x", &byte);
		outputbytes[i/2] = (unsigned char)byte;
	}
	return data;
}

@end


@implementation NSString (sha1)

- (NSData *)sha1Hash
{
	return [[self dataUsingEncoding: NSUTF8StringEncoding] sha1Hash];
}

@end

@implementation NSNumber (sha1)

- (NSData *)sha1Hash
{
	return [[self stringValue] sha1Hash];
}

@end

@implementation NSArray (sha1)

- (NSData *)sha1Hash
{
	NSMutableData *result = [NSMutableData data];
	for (id obj in self)
	{
		[result appendData: [obj sha1Hash]];
	}
	return [result sha1Hash];
}

@end

@implementation NSSet (sha1)

- (NSData *)sha1Hash
{
	NSMutableData *result = [NSMutableData data];
	for (id obj in self)
	{
		[result appendData: [obj sha1Hash]];
	}
	return [result sha1Hash];
}

@end

@implementation NSDate (sha1)

- (NSData *)sha1Hash
{
	return [[self description] sha1Hash];
}

@end

@implementation NSDictionary (sha1)

- (NSData *)sha1Hash
{
	NSMutableData *result = [NSMutableData data];
	for (NSString *key in [self allKeys])
	{
		[result appendData: [key sha1Hash]];
		[result appendData: [[self valueForKey: key] sha1Hash]];
	}
	return [result sha1Hash];
}

@end