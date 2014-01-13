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
	NSLog(@"-textDidChange:");
}

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	NSLog(@"should add %@", replacementString);
	
	if ([replacementString isEqualToString: @""])
		textToDelete = [[[aTextView textStorage] string] substringWithRange: affectedCharRange];
	
	return YES;
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSString *editedText = [[textStorage string] substringWithRange: [textStorage editedRange]];
	
	NSLog(@"Text storage did process editing. %@ edited range: %@ = %@", notification.userInfo, NSStringFromRange([textStorage editedRange]), editedText);
	[textView setNeedsDisplay: YES];
	

	if ([[self objectGraphContext] hasChanges])
	{
		if ([textStorage changeInLength] > 0)
		{
			[self commitWithIdentifier: @"insert-text" descriptionArguments: @[editedText]];
		}
		else if ([textStorage changeInLength] < 0)
		{
			[self commitWithIdentifier: @"delete-text" descriptionArguments: @[textToDelete]];
		}
		else
		{
			[self commitWithIdentifier: @"modify-text" descriptionArguments: @[editedText]];
		}
	}
	else
	{
		NSLog(@"No changes, not committing");
	}
}
@end
