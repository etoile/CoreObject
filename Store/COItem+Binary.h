#import <Foundation/Foundation.h>
#import <CoreObject/COItem.h>

@interface COItem (Binary)

- (NSData *) dataValue;
- (id) initWithData: (NSData *)aData;

@end
