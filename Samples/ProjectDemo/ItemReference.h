#import <Cocoa/Cocoa.h>
#import "COObject.h"
#import "OutlineItem.h"

/**
 * ItemReference is a reference/link object used when embedding (in the
 * compound document sense) one DoucumentItem in another document
 *
 * 
 */
@interface ItemReference : COObject //FIXME: DocumentItem has a 'document' property
{
	OutlineItem *referencedItem;
	OutlineItem *parent;
}

- (id)initWithParent: (OutlineItem*)p referencedItem: (OutlineItem*)ref context: (COEditingContext*)ctx;

- (OutlineItem*)parent;
- (void)setParent:(OutlineItem *)p;

- (OutlineItem*)referencedItem;
- (void)setReferencedItem:(OutlineItem *)p;

- (NSString*)label;

@end