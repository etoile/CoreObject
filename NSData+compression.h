#import <Foundation/NSData.h>

@interface NSData (Compression)

- (NSData *)zlibCompressed;
- (NSData *)zlibDecompressed;

@end
