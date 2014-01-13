#import <Cocoa/Cocoa.h>
#import "EWDocumentWindowController.h"
#import <CoreObject/COAttributedStringWrapper.h>

@interface TextController : EWDocumentWindowController <NSTextViewDelegate, NSTextStorageDelegate>
{
	IBOutlet NSTextView *textView;
	COAttributedStringWrapper *textStorage;
	
	// Hack to save text being deleted for the commit label
	NSString *textToDelete;
	
	NSTimer *coalescingTimer;
}

@end
