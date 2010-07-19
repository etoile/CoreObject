#import <Cocoa/Cocoa.h>

/**
 * Dumb wrapper around property list serialization/deserialization.
 * Probably want to get rid of this.
 */
@interface COSerializer : NSObject
{
}

+ (NSData *) serializeObject: (id)object;
+ (id) unserializeData: (NSData *)data;

@end
