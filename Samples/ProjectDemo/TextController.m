#import "TextController.h"
#import "COEditingContext.h"

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
	return doc;
}

- (void)windowDidLoad
{
	[textView setDelegate: self];
	
	NSString *label = [[doc rootObject] label];
	[[textView textStorage] setAttributedString: [[[NSAttributedString alloc] initWithString: label] autorelease]];	
}

- (void)textDidChange:(NSNotification*)notif
{
	[[doc rootObject] setLabel: [[textView textStorage] string]];
	[[doc objectContext] commitWithType:kCOTypeMinorEdit
					   shortDescription:@"Edit Text"
						longDescription:@"Edit Text"];
}

@end
