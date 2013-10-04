#import "COPatternUndoStack.h"

@implementation COPatternUndoStack

- (void) recordCommand: (COCommand *)aCommand
{
    [NSException raise: NSGenericException format: @"You can't push actions to a COPatternUndoStack"];
}

@end
