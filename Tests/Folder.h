#import <CoreObject/CoreObject.h>

/**
 * Folder has a composite, multivalued, unordered relationship to other folders
 * called 'contents'. Note that it can only contain other Folders.
 */
@interface Folder : COObject

@property (nonatomic, readwrite, strong) NSString *label;
@property (nonatomic, readwrite, strong) NSSet *contents;
@property (nonatomic, readwrite, weak) Folder *parent;

@end
