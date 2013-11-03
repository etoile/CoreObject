#import <Cocoa/Cocoa.h>
#import "Document.h"

@interface TextController : NSWindowController <NSTextViewDelegate>
{
	IBOutlet NSTextView *textView;
	Document *doc; // weak ref
	BOOL isSharing;
}

@end
