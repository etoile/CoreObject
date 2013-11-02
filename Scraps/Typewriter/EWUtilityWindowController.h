#import <Cocoa/Cocoa.h>

/**
 * Abstract superclass for utility window controllers.
 *
 * Currently all it does is return the active document's undo manager
 */
@interface EWUtilityWindowController : NSWindowController

- (void) setInspectedDocument: (NSDocument *)aDoc;

@end
