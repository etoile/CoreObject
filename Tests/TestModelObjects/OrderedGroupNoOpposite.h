#import "TestCommon.h"

/**
 * Test model object that has an ordered many-to-many relationship to COObject
 */
@interface OrderedGroupNoOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;

+ (NSUInteger) countOfDeallocCalls;

@end
