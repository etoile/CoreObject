#import <Cocoa/Cocoa.h>

/**
 * These categories add a sha1Hash method to property lists.
 * A bit hacky..
 */

@interface NSData (sha1)

/**
 * Returns the SHA1 hash of the receiver as an NSData object
 */
- (NSData *)sha1Hash;
/**
 * Returns the SHA1 hash of the receiver as an NSString containting a 
 * hexadecimal representation of the hash.
 */
- (NSString *)sha1HashHexString;

- (NSString *)hexString;
+ (NSData *)dataWithHexString: (NSString*)hex;
@end

@interface NSString (sha1)
- (NSData *)sha1Hash;
@end

@interface NSNumber (sha1)
- (NSData *)sha1Hash;
@end

@interface NSArray (sha1)
- (NSData *)sha1Hash;
@end

@interface NSDictionary (sha1)
- (NSData *)sha1Hash;
@end

@interface NSSet (sha1)
- (NSData *)sha1Hash;
@end

@interface NSDate (sha1)
- (NSData *)sha1Hash;
@end