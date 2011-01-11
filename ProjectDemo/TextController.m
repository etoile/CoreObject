#import "TextController.h"


@implementation TextController

- (id)initWithDocument: (id)document isSharing: (BOOL)sharing;
{
	self = [super initWithWindowNibName: @"TextDocument"];
	
	if (!self) { [self release]; return nil; }
	
	doc = document; // weak ref
	isSharing = sharing;
	
	return self;
}

- (id)initWithDocument: (id)document
{
	return [self initWithDocument:document isSharing: NO];
}

- (Document*)projectDocument
{
	return nil;
}

@end
