#import <Cocoa/Cocoa.h>
#import "EWTypewriterWindowController.h"
#import "EWDocument.h"
#import "EWAppDelegate.h"

@implementation EWTypewriterWindowController

- (void)windowDidLoad
{
    NSLog(@"windowDidLoad %@", textView_);
    
    [[self window] setRestorable: NO];
    
    textStorage_ = [[EWTextStorage alloc] initWithDocumentUUID:
                        [[[[self document] currentPersistentRoot] rootObject] UUID]];
    [textStorage_ setDelegate: self];
    
    [textView_ setDelegate: self];
    [[textView_ layoutManager] replaceTextStorage: textStorage_];
    
    EWDocument *doc = [self document];
    [self displayRevision: [[[[doc currentPersistentRoot] editingBranch] currentRevision] revisionID]];
	
	
	if ([[self document] persistentRoot] == [(EWAppDelegate *)[NSApp delegate] user1PersistentRoot])
	{
		[_pull1 setEnabled: NO];
	}
	else if ([[self document] persistentRoot] == [(EWAppDelegate *)[NSApp delegate] user2PersistentRoot])
	{
		[_pull2 setEnabled: NO];
		[_pull3 setEnabled: NO];
	}
	else
	{
		[_pull2 setEnabled: NO];
		[_pull3 setEnabled: NO];
	}
}

- (void) displayRevision:(CORevisionID *)aRev
{
    if ([displayedRevision_ isEqual: aRev])
    {
        return;
    }
    
    displayedRevision_ =  aRev;
    
    id<COItemGraph> aTree = [[[self document] store] itemGraphForRevisionID: aRev];
    
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

/* NSTextStorage delegate */

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

    // Calculate set of updated items
    NSMutableArray *updatedItems = [NSMutableArray array];
    [updatedItems addObject: [subtree itemForUUID: [subtree rootItemUUID]]];
    
    for (ETUUID *updatedUUID in [textStorage_ paragraphUUIDsChangedDuringEditing])
    {
        COItem *item = [subtree itemForUUID: updatedUUID];
        
        if (item == nil)
        {
            // Sometimes the text storage will report spurious changes
            continue;
        }
        
        [updatedItems addObject: item];
    }
    
    // Make a commit
    [[self document] recordUpdatedItems: updatedItems];
    
//    NSLog(@"subtree: %@", subtree);
//    
//    EWTextStorage *newTs = [[EWTextStorage alloc] init];
//    BOOL success = [newTs setTypewriterDocument: subtree];
//    
//    NSLog(@"newTs: %@, succes: %d", newTs, (int)success);
}
    
@end
