#import <CoreObject/CoreObject.h>

/**
 * Folder has a composite, multivalued, unordered relationship to other folders
 * called 'contents'. Note that it can only contain other Folders.
 */
@interface Folder : COObject

@property (readwrite, strong, nonatomic) NSString *label;
@property (readwrite, strong, nonatomic) NSSet *contents;
@property (readwrite, weak, nonatomic) Folder *parent;

@end
