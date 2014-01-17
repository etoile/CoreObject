#import "EWGraphCell.h"

@implementation EWGraphCell

- (id) init
{
	self = [super init];
	return self;
}

- (id) initImageCell: (NSImage *)image
{
	return [self init];
}

- (id) initTextCell: (NSString *)aString
{
	return [self init];
}

- (id) initWithCoder: (NSCoder *)aDecoder
{
	return [self init];
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame = NSInsetRect(cellFrame, -1, -1);
	
	NSUInteger row = [[self objectValue] unsignedIntegerValue];
	
	[graphRenderer drawRevisionAtIndex: row
								inRect: cellFrame];
}

@end
