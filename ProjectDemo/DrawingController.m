#import "DrawingController.h"

@implementation DrawingController

- (id)initWithDocument: (id)document isSharing: (BOOL)sharing;
{
	self = [super initWithWindowNibName: @"DrawingDocument"];
	
	if (!self) { [self release]; return nil; }
	
	doc = document; // weak ref
	isSharing = sharing;

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (id)initWithDocument: (id)document
{
	return [self initWithDocument:document isSharing: NO];
}


- (void)windowDidLoad
{
	if (!NSIsEmptyRect([doc screenRectValue]))
	{
		// Disable automatic positioning
		[self setShouldCascadeWindows: NO];
		[[self window] setFrame: [doc screenRectValue] display: NO];		
	}
	
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(windowFrameDidChange:)
												 name: NSWindowDidMoveNotification 
											   object: [self window]];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(windowFrameDidChange:)
												 name: NSWindowDidEndLiveResizeNotification 
											   object: [self window]];	
	
	if ([doc documentName])
	{
		NSString *title;
		if (isSharing)
		{
			title = @"Shared Doc";
		}
		else
		{
			title = [doc documentName];
		}
		[[self window] setTitle: title]; 
	}
	
	[graphicView setDrawingController: self];
}

- (void)windowFrameDidChange:(NSNotification*)notification
{
	[doc setScreenRectValue: [[self window] frame]];
	
	assert([[doc objectContext] objectHasChanges: [doc uuid]]);
	assert([[doc valueForProperty: @"screenRect"] isEqual: NSStringFromRect([[self window] frame])]);
	
	[[doc objectContext] commitWithType: kCOTypeMinorEdit
		shortDescription: @"Move Window"
		 longDescription: [NSString stringWithFormat: @"Move to %@", NSStringFromRect([doc screenRectValue])]];	
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
	SKTDrawDocument *drawDoc = [doc rootObject];
	assert([drawDoc isKindOfClass: [SKTDrawDocument class]]);
	return drawDoc;
}

- (Document*)projectDocument
{
	return doc;
}

@end
