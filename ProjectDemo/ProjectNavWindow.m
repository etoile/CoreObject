#import "ProjectNavWindow.h"

@interface ScreenEdgeView : NSView <NSTextFieldDelegate>
{
	NSSearchField *search;
}

@end

@implementation ScreenEdgeView

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame: frameRect];
	
	search = [[[NSSearchField alloc] initWithFrame: NSMakeRect(0,000,100,20)] autorelease];
	[search setDelegate: self];
	[self addSubview: search];
	
	//[self addSubview: [[[NSButton alloc] initWithFrame: NSMakeRect(0,600,100,20)] autorelease]];
	
	/*[self registerForDraggedTypes: [NSArray arrayWithObjects:
									NSPasteboardTypeString,
									nil]];*/
	
	return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSLog(@"Entered");
	return NSDragOperationCopy;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSLog(@"%@", [search stringValue]);
	if (![[search stringValue] isEqual: @""])
	{
		[[NSApp delegate] showSearchResults: nil];
	}
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
- (BOOL) canBecomeKeyWindow
{
	return YES;
}

@end
