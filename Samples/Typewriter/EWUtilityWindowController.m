#import "EWUtilityWindowController.h"

@implementation EWUtilityWindowController

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[[NSDocumentController sharedDocumentController] currentDocument] undoManager];
}

@end
