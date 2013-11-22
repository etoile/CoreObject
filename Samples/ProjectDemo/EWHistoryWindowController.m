#import "EWHistoryWindowController.h"
#import "Document.h"
#import <CoreObject/CoreObject.h>

@implementation EWHistoryWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"History"];
    if (self) {
    }
    return self;
}

+ (EWHistoryWindowController *) sharedController
{
    static EWHistoryWindowController *shared;
    if (shared == nil) {
        shared = [[self alloc] init];
    }
    return shared;
}

- (void) awakeFromNib
{
    [self setShouldCascadeWindows: NO];
    [self setWindowFrameAutosaveName: @"pannerWindow"];
}

- (void) setInspectedWindowController: (EWDocumentWindowController *)aDoc
{
	[self setPersistentRoot: [aDoc persistentRoot]];
}

- (void) storePersistentRootMetadataDidChange: (NSNotification *)notif
{
    NSLog(@"history window: view did change: %@", notif);
    
    [self updateWithProot: persistentRoot_
                    store: [persistentRoot_ store]];
}

- (void) setPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: COPersistentRootDidChangeNotification
                                                  object: persistentRoot_];
    
    persistentRoot_ =  aPersistentRoot;
    
    COBranch *branch = [persistentRoot_ currentBranch];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootMetadataDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: aPersistentRoot];
	
    //NSLog(@"current branch: %@ has %d commits.g v %@", branch, (int)[[branch allCommits] count], graphView_);
    
    [self updateWithProot: persistentRoot_ store: [persistentRoot_ store]];
}

- (void) updateWithProot: (COPersistentRoot *)proot
                   store: (COSQLiteStore *)store
{
	[graphView_ setPersistentRoot: persistentRoot_ branch: [proot currentBranch] store: [persistentRoot_ store]];
}

- (void) sliderChanged: (id)sender
{
    NSLog(@"%lf", [sender doubleValue]);
}

@end
