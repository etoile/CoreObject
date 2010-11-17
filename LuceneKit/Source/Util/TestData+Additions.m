#include "NSData+Additions.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>

@interface TestCompressData: NSObject <UKTest>
@end

@implementation TestCompressData
- (void) testCompresion
{
	NSString *s = @"GNUstep is a free, object-oriented, cross-platform development environment that strives for simplicity and elegance. GNUstep is based on and completely compatible with the OpenStep specification developed by NeXT (now Apple Computer Inc.) as well as implementing many extensions including Mac OS X/Cocoa.";
	NSData *orig = [s dataUsingEncoding: NSUTF8StringEncoding];
	//NSLog(@"Original size %d", [orig length]);
	NSData *compressed = [orig compressedData];
	//NSLog(@"Compressed size %d", [compressed length]);
	NSData *decompressed = [compressed decompressedData];
	//NSLog(@"Decompressed size %d", [decompressed length]);
	UKIntsEqual([orig length], [decompressed length]);
	NSString *d = [[NSString alloc] initWithData: decompressed encoding: NSUTF8StringEncoding];
	UKIntsEqual([s length], [d length]);
	UKStringsEqual(s, d);
}
@end

