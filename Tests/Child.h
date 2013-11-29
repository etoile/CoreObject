#import <CoreObject/CoreObject.h>

@class Parent;

@interface Child : COObject

@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, weak, nonatomic) Parent *parent;

@end
