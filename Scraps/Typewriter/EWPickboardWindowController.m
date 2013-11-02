#import "EWPickboardWindowController.h"

@implementation EWPickboardWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"Pickboard"];
	return self;
}

+ (EWPickboardWindowController *) sharedController
{
    static EWPickboardWindowController *shared;
    if (shared == nil) {
        shared = [[self alloc] init];
    }
    return shared;
}

- (void) setInspectedDocument: (NSDocument *)aDoc
{
    NSLog(@"Inspect %@", aDoc);
}

- (void) show
{
    [self setInspectedDocument: [[NSDocumentController sharedDocumentController]
                                 currentDocument]];
    
    [self showWindow: self];
}

@end
