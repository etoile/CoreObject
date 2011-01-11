#import <Cocoa/Cocoa.h>
#import "Document.h"

#import "SKTLine.h"
#import "SKTCircle.h"
#import "SKTRectangle.h"
#import "SKTTextArea.h"
#import "SKTGraphicView.h"


@interface DrawingController : NSWindowController
{
	Document *doc; // weak ref
	BOOL isSharing;
	Class toolClass;
	IBOutlet SKTGraphicView *graphicView;
}

- (IBAction) selectTool: (id)sender;
- (IBAction) circleTool: (id)sender;
- (IBAction) lineTool: (id)sender;
- (IBAction) rectangleTool: (id)sender;
- (IBAction) textTool: (id)sender;

- (Class)currentGraphicClass; // called by SKTGraphicsView

- (SKTDrawDocument *)drawDocument;

@end
