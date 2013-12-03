#import "TestCommon.h"

/**
 * Test model object that has an ordered multivalued NSString attribute
 */
@interface OrderedAttributeModel : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;
@end