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

+ (NSURL *) defaultDocumentURL
{
	NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
    NSString *dir = [[[libraryDirs objectAtIndex: 0]
                      stringByAppendingPathComponent: @"CoreObjectTypewriter"]
						stringByAppendingPathComponent: @"Store.coreobjectstore"];
	
    [[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: NULL];

	return [NSURL fileURLWithPath: dir isDirectory: YES];
}

- (void) applicationDidFinishLaunching: (NSNotification*)notif
{
	[self makeDocument];
}

- (void) makeDocument
{
	EWDocument *doc = [[EWDocument alloc] initWithStoreURL: [EWAppDelegate defaultDocumentURL]];
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
    return NO;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

@end
