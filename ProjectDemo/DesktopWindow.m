#import "DesktopWindow.h"

@interface DesktopWindowView : NSView
{
	NSImage *bg;
}

@end

@implementation DesktopWindowView

- (id)initWithFrame: (NSRect)r
{
	self = [super initWithFrame: r];
	bg = [[NSImage imageNamed: @"2560x1600"] retain];
	NSLog(@"%@", bg);
	return self;
}

- (void)drawRect: (NSRect)r
{
	[bg drawInRect: [self bounds]
		  fromRect: NSZeroRect
		 operation: NSCompositeSourceOver
		  fraction: 1.0f];
}

- (void)dealloc
{
	[bg release];
	[super dealloc];
}


@end


@implementation DesktopWindow

- (id) init
{	
	NSRect frame = [[NSScreen mainScreen] frame];
	
	self = [super initWithContentRect: frame
							styleMask: NSBorderlessWindowMask
							  backing: NSBackingStoreBuffered
								defer: NO];
	
	
	[self setOpaque:YES];
	[self setHasShadow:NO];
	[self setLevel: CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)];
	[self setBackgroundColor: [NSColor blackColor]];
	[self setReleasedWhenClosed: NO];
	
	[self setContentView: [[[DesktopWindowView alloc] initWithFrame: frame] autorelease]];
	
	[self setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle];
	
	[self orderFront: nil];	
	
	return self;
}


@end
