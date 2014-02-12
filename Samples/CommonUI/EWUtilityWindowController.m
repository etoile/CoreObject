#import "EWUtilityWindowController.h"

@implementation EWUtilityWindowController

- (id)initWithWindowNibName: (NSString*)name
{
    self = [super initWithWindowNibName: name];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(mainWindowDidChange:)
                                                     name: NSWindowDidBecomeMainNotification
                                                   object: nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)mainWindowDidChange: (NSNotification *)notif
{
    NSWindowController *wc = [(NSWindow *)[notif object] windowController];
    
	[self setInspectedWindowController: wc];
}

- (void) setInspectedWindowController: (NSWindowController *)aDoc
{
    [self doesNotRecognizeSelector: _cmd];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[[NSDocumentController sharedDocumentController] currentDocument] undoManager];
}

@end
