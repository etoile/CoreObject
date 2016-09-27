#import "EWOutlineView.h"

@implementation EWOutlineView

@synthesize delegate;

- (void)textDidEndEditing:(NSNotification *)notification
{
    [super textDidEndEditing: notification];

    if ([self.delegate respondsToSelector: @selector(outlineViewDidEndFieldEditor:)])
    {
        [self.delegate outlineViewDidEndFieldEditor: self];
    }
}

- (void)editColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex withEvent:(NSEvent *)theEvent select:(BOOL)flag
{
    if ([self.delegate respondsToSelector: @selector(outlineViewDidStartFieldEditor:)])
    {
        [self.delegate outlineViewDidStartFieldEditor: self];
    }

    [super editColumn: columnIndex row: rowIndex withEvent: theEvent select: flag];
}

@end
