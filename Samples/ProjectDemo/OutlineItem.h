#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "DocumentItem.h"

@interface OutlineItem : DocumentItem

@property (readwrite, nonatomic, retain) NSString *label;
@property (readwrite, nonatomic, retain) OutlineItem *parent;
@property (readwrite, nonatomic, retain) NSArray *contents;

- (OutlineItem*)root;

- (NSArray *)allContents;

- (void) addItem: (OutlineItem*)item;
- (void) addItem: (OutlineItem*)item atIndex: (NSUInteger)index;
- (void) removeItemAtIndex: (NSUInteger)index;

@end