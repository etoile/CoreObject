#import <CoreObject/CoreObject.h>

@interface COAttributedStringChunk : COObject
@property (nonatomic, readwrite, strong) NSString *text;
@property (nonatomic, readwrite, strong) NSString *htmlCode;
@end
