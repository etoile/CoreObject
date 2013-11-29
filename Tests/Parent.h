#import <CoreObject/CoreObject.h>

@class Child;

/**
 * Parent/Child are a simple test case for compsite univalued relationships.
 */
@interface Parent : COObject

@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) Child *child;

@end
