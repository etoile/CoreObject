//
//  NSString+Base64.m
//  Jabber
//
//  Created by David Chisnall on 10/11/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSData+Hash.h"
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/sha.h>
#include <openssl/md5.h>
#include <openssl/ripemd.h>

@implementation NSData (Hash)
- (NSString*)base64String
{
	BIO * mem = BIO_new(BIO_s_mem());
	BIO * b64 = BIO_new(BIO_f_base64());
	BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
	mem = BIO_push(b64, mem);
	BIO_write(mem, [self bytes], [self length]);
	BIO_flush(mem);
	char * base64CString;
	long base64Length = BIO_get_mem_data(mem, &base64CString);
	NSString * encodedString = [[[NSString alloc] initWithBytes: (const void *)base64CString
	                                                    length: base64Length
	                                                  encoding: NSASCIIStringEncoding] autorelease];
	BIO_free_all(mem);
	return encodedString;
}
- (NSString*)ripemd160
{
	unsigned char buffer[20];
	RIPEMD160([self bytes], [self length], buffer);
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			buffer[0],
			buffer[1],
			buffer[2],
			buffer[3],
			buffer[4],
			buffer[5],
			buffer[6],
			buffer[7],
			buffer[8],
			buffer[9],
			buffer[10],
			buffer[11],
			buffer[12],
			buffer[13],
			buffer[14],
			buffer[15],
			buffer[16],
			buffer[17],
			buffer[18],
			buffer[19]];
}
- (NSString*) sha1
{
	unsigned char buffer[20];
	SHA1([self bytes], [self length], buffer);
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			buffer[0],
			buffer[1],
			buffer[2],
			buffer[3],
			buffer[4],
			buffer[5],
			buffer[6],
			buffer[7],
			buffer[8],
			buffer[9],
			buffer[10],
			buffer[11],
			buffer[12],
			buffer[13],
			buffer[14],
			buffer[15],
			buffer[16],
			buffer[17],
			buffer[18],
			buffer[19]];
}
- (NSString*) md5
{
	unsigned char buffer[16];
	MD5([self bytes], [self length], buffer);
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			buffer[0],
			buffer[1],
			buffer[2],
			buffer[3],
			buffer[4],
			buffer[5],
			buffer[6],
			buffer[7],
			buffer[8],
			buffer[9],
			buffer[10],
			buffer[11],
			buffer[12],
			buffer[13],
			buffer[14],
			buffer[15]];
}
@end

@implementation NSString (Base64)
- (NSData*)base64DecodedData
{
    BIO * mem = BIO_new_mem_buf((void *) [self UTF8String], 
		[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
	BIO * b64 = BIO_new(BIO_f_base64());
	BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
	mem = BIO_push(b64, mem);
    
	// Decode into an NSMutableData
	NSMutableData * data = [NSMutableData data];
	char inbuf[512];
	int inlen;
	while ((inlen = BIO_read(mem, inbuf, sizeof(inbuf))) > 0)
	{
		[data appendBytes: inbuf length: inlen];    
	}
	// Clean up and go home
	BIO_free_all(mem);
	return data;	
}
@end
