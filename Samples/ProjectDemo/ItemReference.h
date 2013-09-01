#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import "OutlineItem.h"
#import "DocumentItem.h"

/**
 * ItemReference is a reference/link object used when embedding (in the
 * compound document sense) one DoucumentItem in another document
 *
 * 
 */
@interface ItemReference : DocumentItem

- (id)initWithParent: (OutlineItem*)p referencedItem: (OutlineItem*)ref context: (COObjectGraphContext*)ctx;

@property (readwrite, nonatomic, retain) OutlineItem *parent;
@property (readwrite, nonatomic, retain) OutlineItem *referencedItem;
@property (readonly, nonatomic, retain) NSString *label;

@end