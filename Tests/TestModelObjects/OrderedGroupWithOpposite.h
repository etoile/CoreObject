#import "TestCommon.h"

/**
 * Test model object that has an ordered many-to-many relationship to OrderedGroupContent
 */
@interface OrderedGroupWithOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;
@end
