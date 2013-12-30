#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import <CoreObject/COAttributedString.h>

#import "DocumentItem.h"

@interface TextItem : DocumentItem

@property (nonatomic, readwrite, retain) COAttributedString *attrString;

@end
