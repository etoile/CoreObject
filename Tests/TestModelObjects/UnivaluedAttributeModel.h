#import "TestCommon.h"

/**
 * Test model object that has a univalued NSString attribute
 */
@interface UnivaluedAttributeModel : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@end