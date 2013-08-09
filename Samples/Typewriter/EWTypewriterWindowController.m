#import <Cocoa/Cocoa.h>
#import "EWTypewriterWindowController.h"
#import "EWDocument.h"

@implementation EWTypewriterWindowController

- (void)dealloc
{
    [textStorage_ release];
    [super dealloc];
}

- (void)windowDidLoad
{
    NSLog(@"windowDidLoad %@", textView_);
    
    textStorage_ = [[EWTextStorage alloc] init];
    [textStorage_ setDelegate: self];
    
    [textView_ setDelegate: self];
    [[textView_ layoutManager] replaceTextStorage: textStorage_];
}

- (void) loadDocumentTree: (id <COItemGraph>)aTree
{
    isLoading_ = YES;
    [textStorage_ setTypewriterDocument: aTree];
    isLoading_ = NO;
}

/* NSTextViewDelegate */

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
    NSLog(@"doCommandBySelector: %@", NSStringFromSelector(aSelector));
    
    return NO;
}

/* NSTextStorage */

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification
{
    if (isLoading_)
    {
        NSLog(@"Text change occurred during -loadDocumentTree, so don't create a new commit.");
        return;
    }
    
    NSLog(@"TODO: write the text storage out to the persistent root.");
    NSLog(@"Changed objects were: %@", [textStorage_ paragraphUUIDsChangedDuringEditing]);
    
    id <COItemGraph> subtree = [textStorage_ typewriterDocument];

    // FIXME: should be "Record delata"
    [[self document] recordNewState: subtree];

    
//    NSLog(@"subtree: %@", subtree);
//    
//    EWTextStorage *newTs = [[EWTextStorage alloc] init];
//    BOOL success = [newTs setTypewriterDocument: subtree];
//    
//    NSLog(@"newTs: %@, succes: %d", newTs, (int)success);
}
    
@end
