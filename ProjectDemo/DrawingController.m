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

- (id)initWithDocument: (id)document
{
	return [self initWithDocument:document isSharing: NO];
}


@end
