#import <CoreObject/CoreObject.h>

/**
 * Folder has a composite, multivalued, unordered relationship to other folders
 * called 'contents'. Note that it can only contain other Folders.
 */
@interface Folder : COObject

@property (nonatomic, readwrite, copy) NSString *label;
@property (nonatomic, readwrite, copy) NSSet *contents;
@property (nonatomic, readwrite, weak) Folder *parent;

@end
