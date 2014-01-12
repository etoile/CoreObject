#import <Cocoa/Cocoa.h>
#import "EWDocumentWindowController.h"
#import <CoreObject/COAttributedStringWrapper.h>

@interface TextController : EWDocumentWindowController <NSTextViewDelegate, NSTextStorageDelegate>
{
	IBOutlet NSTextView *textView;
	COAttributedStringWrapper *textStorage;
}

@end
