#import "PreferencesController.h"
#import <CoreObject/CoreObject.h>

@implementation PreferencesController

#define PER_PROJECT 0
#define PER_DOCUMENT 1

- (id)init
{
	self = [super initWithWindowNibName: @"Preferences"];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(defaultsChanged:)
													 name: NSUserDefaultsDidChangeNotification
												   object: nil];
	}
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) defaultsChanged: (NSNotification*)notif
{
	NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey: @"UndoMode"];
	if ([mode isEqual: @"Project"] || mode == nil)
	{
		[undoMode selectCellWithTag: PER_PROJECT];
	}
	else if ([mode isEqual: @"Document"])
	{
		[undoMode selectCellWithTag: PER_DOCUMENT];
	}
}

- (void)awakeFromNib
{
	[self defaultsChanged: nil];
}

- (IBAction) undoModeChanged: (id)sender
{
	NSInteger tag = [((NSMatrix *)sender) selectedTag];
	NSString *value = nil;
	
	if (tag == PER_PROJECT)
	{
		value = @"Project";
		[[COUndoTrack trackForName: @"org.etoile.projectdemo" withEditingContext: nil] clear];
		NSLog(@"Cleared project stack");
 	}
	else if (tag == PER_DOCUMENT)
	{
		value = @"Document";
		[[COUndoTrack trackForPattern: @"org.etoile.projectdemo-*" withEditingContext: nil] clear];
		NSLog(@"Cleared document stacks");
	}
	
	[[NSUserDefaults standardUserDefaults] setValue: value forKey: @"UndoMode"];
	NSLog(@"changed to %@", value);
	
	// Clear the undo stacks
	
	
}

@end
