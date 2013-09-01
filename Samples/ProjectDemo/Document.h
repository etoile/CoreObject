#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "Tag.h"

@interface Document : COObject

- (NSRect) screenRectValue;
- (void) setScreenRectValue:(NSRect)r;

- (BOOL) isOpen;
- (void) setIsOpen:(BOOL)i;

@property (readwrite, nonatomic, retain) NSString *documentType;
@property (readwrite, nonatomic, retain) COObject *rootObject;
@property (readwrite, nonatomic, retain) NSString *documentName;
@property (readwrite, nonatomic, retain) NSSet *tags;

- (void) addTag: (Tag *)tag;
- (void) removeTag: (Tag *)tag;

@end
