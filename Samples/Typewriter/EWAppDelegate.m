/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import "EWAppDelegate.h"
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/CoreObject.h>

#import "EWDocument.h"

@implementation EWAppDelegate

- (void) applicationDidFinishLaunching: (NSNotification*)notif
{
	[self orderFrontTypewriter: nil];
}

- (void) makeDocument
{
	EWDocument *doc = [[EWDocument alloc] init];
	[[NSDocumentController sharedDocumentController] addDocument: doc];
	[doc makeWindowControllers];
	[doc showWindows];
}

- (IBAction) orderFrontTypewriter: (id)sender
{
	NSDocumentController *dc = [NSDocumentController sharedDocumentController];
	
	if ([[dc documents] isEmpty])
	{
		[self makeDocument];
	}
	else
	{
		[[dc documents][0] showWindows];
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

@end
