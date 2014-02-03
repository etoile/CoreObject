#import "EWGraphLabelCell.h"

@implementation EWGraphLabelCell

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

- (NSString *) prettyPrintBranch: (COBranch *)aBranch
{
	NSString *prootLabel = aBranch.persistentRoot.metadata[@"documentName"];
	NSString *branchLabel = aBranch.label;
	NSString *type = (aBranch.isCurrentBranch) ? @"current" : @"head";
	
	return [NSString stringWithFormat: @"[%@ : %@ (%@)]", prootLabel, branchLabel, type];
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSUInteger row = [[self objectValue] unsignedIntegerValue];
	
	CORevision *revision = [graphRenderer revisionAtIndex: row];
	NSArray *branches = [graphRenderer branchesForIndex: row];
	
	NSMutableString *desc = [NSMutableString new];

	for (COBranch *branch in branches)
	{
		[desc appendString: [self prettyPrintBranch: branch]];
	}
	
	if ([revision localizedShortDescription] != nil)
		[desc appendString: [revision localizedShortDescription]];
	
	[desc drawInRect: cellFrame withAttributes: @{}];
}

@end
