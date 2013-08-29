#import "CheckpointAsSheetController.h"

@implementation CheckpointAsSheetController

- (NSString*) showSheet
{
	didSave = NO;
	
	[NSApp beginSheet: sheet
	   modalForWindow: nil
		modalDelegate: nil
	   didEndSelector: NULL
		  contextInfo: nil];
	
	[NSApp runModalForWindow: sheet];
	[NSApp endSheet: sheet];
	[sheet orderOut: self];
	
	if (didSave)  
	{
		return [formCell stringValue];
	}
	else
	{
		return nil;
	}
}

- (void)save: (id)sender
{
	didSave = YES;
	[NSApp stopModal];
}

- (void)cancel: (id)sender
{
	[NSApp stopModal];
}

@end
