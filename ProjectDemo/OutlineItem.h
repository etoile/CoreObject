#import <Cocoa/Cocoa.h>
#import "COObject.h"

@interface OutlineItem : COObject
{
  NSMutableArray *contents;
  NSString *label;
  OutlineItem *parent;
  
  // notification hack - remove when we can use KVO
  id delegate;
  
}

- (NSString*)label;
- (void)setLabel:(NSString*)l;

- (OutlineItem*)parent;
- (void)setParent:(OutlineItem *)p;

- (NSArray *)contents;
- (NSArray *)allContents;

- (void) addItem: (OutlineItem*)item;
- (void) addItem: (OutlineItem*)item atIndex: (NSUInteger)index;
- (void) removeItemAtIndex: (NSUInteger)index;

// notification hack - remove when we can use KVO
@property (nonatomic, assign, readwrite) id delegate;

@end

@interface NSObject (OutlineItemDelegate)
- (void)outlineItemDidChange: (OutlineItem*)item;
@end