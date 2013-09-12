#import <CoreObject/CoreObject.h>

@interface OutlineItem : COContainer

@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;
@property (weak, readonly, nonatomic) OutlineItem *parentContainer;
@property (strong, readonly, nonatomic) NSSet *parentCollections;
@property (readwrite, nonatomic, getter=isChecked, setter=setChecked:) BOOL checked;

@end
