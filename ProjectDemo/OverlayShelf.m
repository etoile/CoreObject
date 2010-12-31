#import "OverlayShelf.h"


@interface OverlayShelfView : NSView
{
	NSImage *stamp;
}

@end

@implementation OverlayShelfView

- (id)initWithFrame: (NSRect)r
{
	self = [super initWithFrame: r];
	stamp = [[NSImage imageNamed: @"stamp"] retain];

	return self;
}

- (void)drawRect: (NSRect)r
{
	[[NSColor colorWithCalibratedRed: 0.0 green: 0.0 blue: 0.0 alpha: 0.6] set];
	[NSBezierPath fillRect: [self bounds]];
		
	NSRect stampRect;
	stampRect.size = NSMakeSize(256,256);
	stampRect.origin = NSMakePoint(([self bounds].size.width/2) - (stampRect.size.width / 2),
								   ([self bounds].size.height/2) - (stampRect.size.height / 2));
	
	[stamp drawInRect: stampRect
		  fromRect: NSZeroRect
		 operation: NSCompositeSourceOver
		  fraction: 1.0f];
}

- (void)dealloc
{
	[stamp release];
	[super dealloc];
}


@end


@implementation OverlayShelf

- (id) init
{	
	NSRect frame = [[NSScreen mainScreen] frame];
	
	self = [super initWithContentRect: frame
							styleMask: NSBorderlessWindowMask
							  backing: NSBackingStoreBuffered
								defer: NO];
	
	[self setOpaque:NO];
	[self setHasShadow:NO];
	[self setLevel: NSMainMenuWindowLevel - 1];
	[self setBackgroundColor: [NSColor clearColor]];
	[self setIgnoresMouseEvents: NO];
	[self setReleasedWhenClosed: NO];
	
	[self setContentView: [[[OverlayShelfView alloc] initWithFrame: frame] autorelease]];
	
	[self setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle];
	
	//[self orderFront: nil];	
	
	return self;
}


@end
