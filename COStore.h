#import <EtoileFoundation/ETUUID.h>

/**
 * COStore is a very simple wrapper around a directory which lets
 * you create/read files using dataForKey: and setData:forKey:.
 *
 * It could transparently compress the data (currently disabled for testing)
 * In the future I will implement something like mercurial revlogs or
 * git packed store to keep the size down.
 */
@interface COStore : NSObject
{
	NSURL *_url;
	
}
- (id) initWithURL: (NSURL *)url;
+ (COStore *)storeWithURL: (NSURL *)url;

- (NSData *)dataForKey: (NSString *)key;
- (BOOL)setData: (NSData *)data forKey: (NSString*)key;
- (void)removeDataForKey: (NSString *)key;

@end