#import <Cocoa/Cocoa.h>
#import "COObject.h"
#import "Document.h"

@interface Project : COObject
{
	NSMutableSet *documents;
	
	// notification hack - remove when we can use KVO
	id delegate;
}

- (NSArray*) documents;
- (void) addDocument: (Document *)document;
- (void) removeDocument: (Document *)document;

// notification hack - remove when we can use KVO
@property (nonatomic, assign, readwrite) id delegate;

@end

@interface NSObject (ProjectDelegate)
- (void)projectDocumentsDidChange: (Project*)p;
@end