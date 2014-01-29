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
	
	[[self undoTrack] beginCoalescing];
}

- (void)textDidChange:(NSNotification*)notif
{
	NSLog(@"-textDidChange:");
}

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	changedByUser = YES;
	
	NSLog(@"should add %@", replacementString);
	
	// These are just used to provide commit metadata
	
	if (affectedCharRange.length > 0)
		affectedText = [[[aTextView textStorage] string] substringWithRange: affectedCharRange];
	else
		affectedText = @"";
	
	replacementText = replacementString;

	return YES;
}

static NSString *Trim(NSString *text)
{
	if ([text length] > 30)
		return [[text substringToIndex: 30] stringByAppendingFormat: @"%C", (unichar)0x2026 /* elipsis */ ];
	
	text = [text stringByReplacingOccurrencesOfString: @"\n" withString: @""];
	
	return text;
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSString *editedText = [[textStorage string] substringWithRange: [textStorage editedRange]];
	
	NSLog(@"Text storage did process editing. %@ edited range: %@ = %@", notification.userInfo, NSStringFromRange([textStorage editedRange]), editedText);
	[textView setNeedsDisplay: YES];
	
	if (changedByUser)
	{
		changedByUser = NO;
	}
	else if ([[self objectGraphContext] hasChanges])
	{
		NSLog(@"Processing editing with changes, but it wasn't the user's changes, ignoring");
		return;
	}

	if ([[self objectGraphContext] hasChanges])
	{
		if (replacementText == nil && [affectedText length] > 0)
		{
			[self commitWithIdentifier: @"modify-text" descriptionArguments: @[Trim(affectedText)]];
		}
		else if ([replacementText isEqualToString: @""] && [affectedText length] > 0)
		{
			[self commitWithIdentifier: @"delete-text" descriptionArguments: @[Trim(affectedText)]];
		}
		else if ([replacementText length] > 0 && [affectedText isEqualToString: @""])
		{
			[self commitWithIdentifier: @"insert-text" descriptionArguments: @[Trim(replacementText)]];
		}
		else if ([replacementText length] > 0 && [affectedText length] > 0)
		{
			[self commitWithIdentifier: @"replace-text" descriptionArguments: @[Trim(affectedText), Trim(replacementText)]];
		}
		else
		{
			NSLog(@"%@: got -textStorageDidProcessEditing:, but it wasn't caused by us.. ignoring", self);
		}
		
		if (coalescingTimer != nil)
		{
			[coalescingTimer invalidate];
		}
		coalescingTimer = [NSTimer scheduledTimerWithTimeInterval: 2 target: self selector: @selector(calescingTimer:) userInfo: nil repeats: NO];
	}
	else
	{
		NSLog(@"No changes, not committing");
	}
}

- (void) calescingTimer: (NSTimer *)timer
{
	NSLog(@"Breaking coalescing...");
	[[self undoTrack] endCoalescing];
	[[self undoTrack] beginCoalescing];
	
	[coalescingTimer invalidate];
	coalescingTimer = nil;
}

- (void) objectGraphDidChange
{
	NSLog(@"Text Object graph did change");
}

- (void) objectGraphContextDidSwitch
{
	NSLog(@"Text Object graph did switch");

	// v1
//
//	textStorage.backing = [[self textDocument] attrString];
	
	// v2
	
	@autoreleasepool
	{
		NSLog(@"Text Object graph will switch from %@ (%p)", textStorage, textStorage);
		[textStorage removeLayoutManager: [textView layoutManager]];
		textStorage = nil;
	}
	
	textStorage = [[COAttributedStringWrapper alloc] initWithBacking: [[self textDocument] attrString]];
	
	NSLog(@"Text Object graph will switch to %@ (%p)", textStorage, textStorage);
	
	[textStorage setDelegate: self];
	[textStorage addLayoutManager: [textView layoutManager]];

	NSLog(@"Text Object graph did switch to %@ (%p)", textStorage, textStorage);
}

@end
