#import <Cocoa/Cocoa.h>
#import "Document.h"

@interface DrawingController : NSWindowController
{
	Document *doc; // weak ref
	BOOL isSharing;
}

@end
