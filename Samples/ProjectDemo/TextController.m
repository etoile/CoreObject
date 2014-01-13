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
	NSLog(@"should add %@", replacementString);
	
	if ([replacementString isEqualToString: @""])
		textToDelete = [[[aTextView textStorage] string] substringWithRange: affectedCharRange];
	
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
	

	if ([[self objectGraphContext] hasChanges])
	{
		if ([textStorage changeInLength] > 0)
		{
			[self commitWithIdentifier: @"insert-text" descriptionArguments: @[Trim(editedText)]];
		}
		else if ([textStorage changeInLength] < 0)
		{
			[self commitWithIdentifier: @"delete-text" descriptionArguments: @[Trim(textToDelete)]];
		}
		else
		{
			[self commitWithIdentifier: @"modify-text" descriptionArguments: @[Trim(editedText)]];
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

@end
