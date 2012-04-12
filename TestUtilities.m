#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "NSData+sha1.h"
#import "NSData+compression.h"

@interface TestUtilities : NSObject <UKTest>
{
}
@end


@implementation TestUtilities

- (void) testHash
{
	char *str = "The quick brown fox jumps over the lazy dog";
	
	UKStringsEqual(@"2fd4e1c67a2d28fced849ee1bb76e7391b93eb12",
				   [[NSData dataWithBytes:str length:strlen(str)] sha1HashHexString]);

	UKStringsEqual(@"da39a3ee5e6b4b0d3255bfef95601890afd80709",
				   [[NSData data] sha1HashHexString]);

	UKObjectsEqual([NSData dataWithHexString: @"da39a3ee5e6b4b0d3255bfef95601890afd80709"],
				   [[NSData data] sha1Hash]);
}

- (void) testCompression
{
	NSString *string = @"Angels and ministers of grace defend us! Be thou a spirit of health or goblin damn'd, Bring with thee airs from heaven or blasts from hell, Be thy intents wicked or charitable, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me! Angels and ministers of grace defend us! Be thou a spirit of health or goblin damn'd, Bring with thee airs from heaven or blasts from hell, Be thy intents wicked or charitable, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me!";
	
	const char *bytes = [string UTF8String];
	NSData *uncompressed = [NSData dataWithBytes: bytes
										  length: strlen(bytes)];
	
	NSData *compressed = [uncompressed zlibCompressed];
	UKTrue([compressed length] < [uncompressed length]);
	
	NSData *decompressed = [compressed zlibDecompressed];
	UKObjectsEqual(uncompressed, decompressed);
	
	UKNotNil([[NSData data] zlibCompressed]);
	UKObjectsEqual([[[NSData data] zlibCompressed] zlibDecompressed], [NSData data]);
}


@end
