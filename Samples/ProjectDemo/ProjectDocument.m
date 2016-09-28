#import "ProjectDocument.h"

@implementation ProjectDocument

- (instancetype)init
{
    SUPERINIT;
    if (self)
    {

        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.

    }
    return self;
}

- (void)makeWindowControllers
{

}

- (void)windowControllerDidLoadNib: (NSWindowController *)aController
{
    [super windowControllerDidLoadNib: aController];
}


@end
