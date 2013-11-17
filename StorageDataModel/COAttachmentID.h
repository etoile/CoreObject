#import <Foundation/Foundation.h>

@interface COAttachmentID : NSObject
{
	NSData *_data;
}

- (instancetype) initWithData: (NSData *)aData;
- (NSData *) dataValue;

@end
