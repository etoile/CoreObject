#import "ProjectNavWindow.h"

@interface ScreenEdgeView : NSView
{
}

@end

@implementation ScreenEdgeView

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame: frameRect];
	
	[self addSubview: [[NSButton alloc] initWithFrame: NSMakeRect(0,0,100,100)]];
	
	[self registerForDraggedTypes: [NSArray arrayWithObjects:
									NSPasteboardTypeString,
									nil]];
	
	return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSLog(@"Entered");
	return NSDragOperationCopy;
}

@end




@implementation ProjectNavWindow

- (id) init
{
	const CGFloat shelfWidth = 104;
	
	NSRect frame = [[NSScreen mainScreen] frame];
	frame.origin.x = 0;
	frame.size.width = shelfWidth;
	
	self = [super initWithContentRect: frame
							styleMask: NSBorderlessWindowMask
							  backing: NSBackingStoreBuffered
								defer: NO];

	[self setOpaque:NO];
	[self setHasShadow:YES];
	[self setLevel: NSMainMenuWindowLevel - 2];
	//[self setBackgroundColor: [NSColor clearColor]];
	
	[self setBackgroundColor: [NSColor colorWithCalibratedRed:0.725 green:0.682 blue:0.780 alpha:1.00]];
	[self setIgnoresMouseEvents: NO];
	
	[self setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle];
	
	NSView *view = [[[ScreenEdgeView alloc] initWithFrame: NSMakeRect(0, 0, frame.size.width, frame.size.height)] autorelease];
	[self setContentView: view];
	
	[self orderFront: nil];	
	
	return self;
}

@end
