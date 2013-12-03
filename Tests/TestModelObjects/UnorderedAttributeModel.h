#import "TestCommon.h"

/**
 * Test model object that has an unordered multivalued NSString attribute
 */
@interface UnorderedAttributeModel : COObject
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *contents;
@end