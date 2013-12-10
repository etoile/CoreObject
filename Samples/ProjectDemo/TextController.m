#import "TextController.h"
#import <CoreObject/CoreObject.h>
#import "TextItem.h"

@implementation TextController

- (instancetype) initAsPrimaryWindowForPersistentRoot: (COPersistentRoot *)aPersistentRoot
											 windowID: (NSString*)windowID
{
	self = [super initAsPrimaryWindowForPersistentRoot: aPersistentRoot
											  windowID: windowID
										 windowNibName: @"TextDocument"];
	return self;
}

- (instancetype) initPinnedToBranch: (COBranch *)aBranch
						   windowID: (NSString*)windowID
{
	self = [super initPinnedToBranch: aBranch
							windowID: windowID
					   windowNibName: @"TextDocument"];
	return self;
}

- (TextItem *)textDocument
{
	TextItem *textDoc = (TextItem *)[[self projectDocument] rootDocObject];
	assert([textDoc isKindOfClass: [TextItem class]]);
	return textDoc;
}

- (Document*)projectDocument
{
	return [self.objectGraphContext rootObject];
}

- (void) objectGraphDidChange
{
	NSString *label = [[self textDocument] label];
	if (label == nil)
		label = @"";
	
	[[textView textStorage] setAttributedString: [[NSAttributedString alloc] initWithString: label]];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[textView setDelegate: self];

	[self objectGraphDidChange];
}

- (void)textDidChange:(NSNotification*)notif
{
	NSLog(@"-textDidChange: committing.");
	[[self textDocument] setLabel: [[textView textStorage] string]];
	[self commitWithIdentifier: @"edit-text"];
}

@end
