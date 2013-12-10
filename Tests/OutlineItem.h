#import <CoreObject/CoreObject.h>

@interface OutlineItem : COContainer

@property (nonatomic, readwrite) BOOL isShared;
@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSArray *contents;
@property (weak, readonly, nonatomic) OutlineItem *parentContainer;
@property (strong, readonly, nonatomic) NSSet *parentCollections;
@property (readwrite, nonatomic, getter=isChecked, setter=setChecked:) BOOL checked;
@property (readwrite, strong, nonatomic) COAttachmentID *attachmentID;

@end

/* OutlineItem variant to test a composite/container transient relationship */
@interface TransientOutlineItem : COContainer

@property (nonatomic, readwrite, strong) NSArray *contents;
@property (nonatomic, readwrite, weak) TransientOutlineItem *parentContainer;

@end

