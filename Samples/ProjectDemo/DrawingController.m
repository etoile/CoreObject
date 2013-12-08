#import "DrawingController.h"
#import "SKTDrawDocument.h"

@implementation DrawingController

- (instancetype) initAsPrimaryWindowForPersistentRoot: (COPersistentRoot *)aPersistentRoot
											 windowID: (NSString*)windowID
{
	self = [super initAsPrimaryWindowForPersistentRoot: aPersistentRoot
											  windowID: windowID
										 windowNibName: @"DrawingDocument"];
	return self;
}

- (instancetype) initPinnedToBranch: (COBranch *)aBranch
						   windowID: (NSString*)windowID
{
	self = [super initPinnedToBranch: aBranch
							windowID: windowID
					   windowNibName: @"DrawingDocument"];
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	[graphicView setDrawingController: self];
}

- (void) setToolClass: (Class)class
{
	toolClass = class;
	NSLog(@"Tool class: %@", NSStringFromClass(toolClass));
}

/* IB Actions */

- (IBAction) selectTool: (id)sender
{
	[self setToolClass: Nil];
}
- (IBAction) circleTool: (id)sender
{
	[self setToolClass: [SKTCircle class]];
}
- (IBAction) lineTool: (id)sender
{
	[self setToolClass: [SKTLine class]];
}
- (IBAction) rectangleTool: (id)sender
{
	[self setToolClass: [SKTRectangle class]];
}
- (IBAction) textTool: (id)sender
{
	[self setToolClass: [SKTTextArea class]];
}

- (Class)currentGraphicClass
{
	return toolClass;
}

- (SKTDrawDocument *)drawDocument
{
	SKTDrawDocument *drawDoc = (SKTDrawDocument *)[[self projectDocument] rootDocObject];
	assert([drawDoc isKindOfClass: [SKTDrawDocument class]]);
	return drawDoc;
}

- (Document*)projectDocument
{
	return [self.objectGraphContext rootObject];
}

- (void) objectGraphDidChange
{
	[graphicView setNeedsDisplay: YES];
}

@end
