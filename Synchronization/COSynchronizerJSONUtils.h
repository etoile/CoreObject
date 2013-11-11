#import <Foundation/Foundation.h>

@interface COSynchronizerJSONUtils : NSObject

+ (NSString *) serializePropertyList: (id)plist;
+ (id) deserializePropertyList: (NSString *)aString;

+ (id) propertyListForRevisionsArray: (NSArray *)revs;
+ (NSArray *) revisionsArrayForPropertyList: (id)aPropertylist;

@end
