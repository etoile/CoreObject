#import <CoreObject/CoreObject.h>

@interface Tag : COGroup

@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *contents;

@property (readwrite, strong, nonatomic) NSSet *childTags;
@property (weak, readonly, nonatomic) Tag *parentTag;

@end
