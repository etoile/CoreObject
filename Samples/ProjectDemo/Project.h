#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "Document.h"
#import "Tag.h"

@interface Project : COObject

@property (readwrite, nonatomic, retain) NSSet *documents;
@property (readwrite, nonatomic, retain) NSSet *tags;

@end
