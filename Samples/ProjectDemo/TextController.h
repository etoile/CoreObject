#import <Cocoa/Cocoa.h>
#import "EWDocumentWindowController.h"
#import <CoreObject/COAttributedStringWrapper.h>

@interface TextController : EWDocumentWindowController <NSTextViewDelegate>
{
	IBOutlet NSTextView *textView;
	COAttributedStringWrapper *textStorage;
}

@end
