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
	assert([[textDoc attrString] isKindOfClass: [COAttributedString class]]);
	return textDoc;
}

- (Document*)projectDocument
{
	return [self.objectGraphContext rootObject];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[textView setDelegate: self];

	textStorage = [[COAttributedStringWrapper alloc] initWithBacking: [[self textDocument] attrString]];
	[textStorage addLayoutManager: [textView layoutManager]];
	[textStorage setDelegate: self];
}

- (void)textDidChange:(NSNotification*)notif
{
	NSLog(@"-textDidChange: committing.");
	
	[self commitWithIdentifier: @"edit-text"];
}

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	NSLog(@"should add %@", replacementString);
	return YES;
}


- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSLog(@"Text storage did process editing. %@ edited range: %@", notification.userInfo, NSStringFromRange([textStorage editedRange]));
}
@end
