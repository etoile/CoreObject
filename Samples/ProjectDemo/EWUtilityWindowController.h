#import <Cocoa/Cocoa.h>
#import "Document.h"

/**
 * Abstract superclass for utility window controllers.
 *
 * Currently all it does is return the active document's undo manager
 */
@interface EWUtilityWindowController : NSWindowController

- (void) setInspectedDocument: (Document *)aDoc;

@end
