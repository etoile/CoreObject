#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@interface Tag : COObject

@property (readwrite, nonatomic, retain) NSString *label;

@end