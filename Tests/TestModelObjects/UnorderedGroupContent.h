#import "TestCommon.h"

/**
 * Test model object to be inserted as content in UnorderedGroupWithOpposite
 */
@interface UnorderedGroupContent : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *parentGroups;
@end