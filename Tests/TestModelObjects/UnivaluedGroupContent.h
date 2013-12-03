#import "TestCommon.h"

/**
 * Test model object to be inserted as content in UnivaluedGroupWithOpposite
 */
@interface UnivaluedGroupContent : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *parents;
@end