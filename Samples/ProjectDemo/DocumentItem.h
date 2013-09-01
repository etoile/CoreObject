#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>

@class Document;

@interface DocumentItem : COObject

@property (readwrite, nonatomic, retain) Document *document;

@end

