#import "TestCommon.h"
/**
 * Test model object that has an univalued relationship to COObject (no opposite)
 */
@interface UnivaluedGroupNoOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) COObject *content;

+ (NSUInteger) countOfDeallocCalls;

@end