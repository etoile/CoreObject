#import "TestCommon.h"

@class UnivaluedGroupContent;

/**
 * Test model object that has an univalued relationship to UnivaluedGroupContent
 */
@interface UnivaluedGroupWithOpposite: COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) UnivaluedGroupContent *content;
@end