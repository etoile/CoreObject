#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "Tag.h"

@interface Document : COObject
{
	/** 
	 * Note that primitiveScreenRect and isOpen are persistent properties, 
	 * but shouldn't be shared when collaborating.
	 */
	NSRect primitiveScreenRect;
	BOOL isOpen;
	NSString *documentType;
	id rootObject;
	NSString *documentName;
	NSMutableSet *tags;
}

- (NSRect) screenRectValue;
- (void) setScreenRectValue:(NSRect)r;

- (BOOL) isOpen;
- (void) setIsOpen:(BOOL)i;
- (NSString*) documentType;
- (void) setDocumentType:(NSString*)t;
- (id) rootObject;
- (void) setRootObject:(id)r;
- (NSString*)documentName;
- (void)setDocumentName:(NSString *)n;

- (NSSet*) tags;
- (void) addTag: (Tag *)tag;
- (void) removeTag: (Tag *)tag;

@end
