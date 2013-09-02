#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "Tag.h"

@interface Document : COObject

- (NSRect) screenRect;
- (void) setScreenRect:(NSRect)r;

- (BOOL) isOpen;
- (void) setIsOpen:(BOOL)i;

@property (readwrite, nonatomic, retain) NSString *documentType;
@property (readwrite, nonatomic, retain) COObject *rootDocObject;
@property (readwrite, nonatomic, retain) NSString *documentName;
@property (readwrite, nonatomic, retain) NSSet *docTags;

- (void) addDocTagToDocument: (Tag *)tag;
- (void) removeDocTagFromDocument: (Tag *)tag;

@end
