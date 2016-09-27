/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "EWAppDelegate.h"
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/CoreObject.h>
#import "EWTypewriterWindowController.h"

@implementation EWAppDelegate

- (void) applicationDidFinishLaunching: (NSNotification*)notif
{
    windowController = [[EWTypewriterWindowController alloc] initWithWindowNibName: @"Document"];
    [self orderFrontTypewriter: self];
}

- (IBAction) orderFrontTypewriter: (id)sender
{
    [windowController showWindow: self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    [self orderFrontTypewriter: sender];
    return NO;
}

#pragma mark -

@synthesize editingContext = ctx;
@synthesize libraryPersistentRoot = library;

#pragma mark - initialization

- (instancetype) initWithStoreURL: (NSURL *)aURL
{
    self = [super init];
    
    ctx = [COEditingContext contextWithURL: aURL];
    
    NSSet *libraryPersistentRoots = [[ctx persistentRoots] filteredSetUsingPredicate:
                                     [NSPredicate predicateWithBlock: ^(id object, NSDictionary *bindings)
                                      {
                                          COPersistentRoot *persistentRoot = object;
                                          return [[persistentRoot rootObject] isKindOfClass: [COLibrary class]];
                                      }]];
    
    if ([libraryPersistentRoots count] == 0)
    {
        library = [ctx insertNewPersistentRootWithEntityName: @"COTagLibrary"];
        [ctx commit];
    }
    else if ([libraryPersistentRoots count] == 1)
    {
        library = [libraryPersistentRoots anyObject];
    }
    else
    {
        [NSException raise: NSGenericException format: @"Expected only a single library"];
    }
    
    NSLog(@"Library is %@", library);
    
    utilityWindowControllers = [NSMutableArray new];
    
    return self;
}

+ (NSURL *) defaultDocumentURL
{
    NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    
    NSString *dir = [[[libraryDirs objectAtIndex: 0]
                      stringByAppendingPathComponent: @"CoreObject"]
                     stringByAppendingPathComponent: @"Typewriter.coreobjectstore"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: NULL];
    
    return [NSURL fileURLWithPath: dir isDirectory: YES];
}

- (id)init
{
    return [self initWithStoreURL: [[self class] defaultDocumentURL]];
}

- (void) addWindowController: (NSWindowController *)aController
{
    [utilityWindowControllers addObject: aController];
}

- (void) removeWindowController: (NSWindowController *)aController
{
    [utilityWindowControllers removeObject: aController];
}

- (IBAction) orderFrontPreferences: (id)sender
{
    prefsController = [[PreferencesController alloc] init];
    [prefsController showWindow: nil];
}

- (void) clearUndo
{
    [windowController.undoTrack clear];
}

@end
