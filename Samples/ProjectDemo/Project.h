#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "Document.h"
#import "Tag.h"

@interface Project : COObject
{
	NSMutableSet *documents;
	NSMutableSet *tags;
	
	// notification hack - remove when we can use KVO
	id delegate;
}

- (NSArray*) documents;
- (void) addDocument: (Document *)document;
- (void) removeDocument: (Document *)document;

- (NSSet*) tags;
- (void) addTag: (Tag *)tag;
- (void) removeTag: (Tag *)tag;

// notification hack - remove when we can use KVO
@property (nonatomic, assign, readwrite) id delegate;

@end

@interface NSObject (ProjectDelegate)
- (void)projectDocumentsDidChange: (Project*)p;
@end