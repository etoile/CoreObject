#import <Cocoa/Cocoa.h>
#import "EWDocumentWindowController.h"

@interface TextController : EWDocumentWindowController <NSTextViewDelegate>
{
	IBOutlet NSTextView *textView;
}

@end
