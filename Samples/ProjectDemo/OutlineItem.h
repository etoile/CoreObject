#import <Cocoa/Cocoa.h>
#import "COObject.h"

@interface OutlineItem : COObject //FIXME: DocumentItem has a 'document' property
{
	NSMutableArray *contents;
	NSString *label;
	OutlineItem *parent;
}

- (NSString*)label;
- (void)setLabel:(NSString*)l;

- (OutlineItem*)parent;
- (void)setParent:(OutlineItem *)p;

- (OutlineItem*)root;

- (NSArray *)contents;
- (NSArray *)allContents;

- (void) addItem: (OutlineItem*)item;
- (void) addItem: (OutlineItem*)item atIndex: (NSUInteger)index;
- (void) removeItemAtIndex: (NSUInteger)index;

@end