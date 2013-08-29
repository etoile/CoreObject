#import <Cocoa/Cocoa.h>
#import "Document.h"

@interface TextController : NSWindowController
{
	IBOutlet NSTextView *textView;
	Document *doc; // weak ref
	BOOL isSharing;
}

@end
