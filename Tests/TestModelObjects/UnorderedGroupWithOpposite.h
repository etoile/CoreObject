#import "TestCommon.h"

/**
 * Test model object that has an unordered many-to-many relationship to UnorderedGroupContent
 */
@interface UnorderedGroupWithOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *contents;
@end