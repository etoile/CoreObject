#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

#import "DocumentItem.h"

@interface TextItem : DocumentItem

@property (nonatomic, readwrite, retain) NSString *label;

@end