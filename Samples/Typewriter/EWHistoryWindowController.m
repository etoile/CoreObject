#import "EWHistoryWindowController.h"
#import "EWDocument.h"
#import <CoreObject/CoreObject.h>

@implementation EWHistoryWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"History"];
    if (self) {
    }
    return self;
}

- (void) dealloc
{
    [persistentRoot_ release];
    [super dealloc];
}


+ (EWHistoryWindowController *) sharedController
{
    static EWHistoryWindowController *shared;
    if (shared == nil) {
        shared = [[self alloc] init];
    }
    return shared;
}

- (void) setInspectedDocument: (NSDocument *)aDoc
{
    NSLog(@"Inspect %@", aDoc);
    
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: COPersistentRootDidChangeNotification
                                                  object: persistentRoot_];
    
    COPersistentRoot *proot = [(EWDocument *)aDoc currentPersistentRoot];
    ASSIGN(persistentRoot_, proot);
    
    [self updateWithProot: proot
                    store: [(EWDocument *)aDoc store]];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootMetadataDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: proot];
}

- (void) updateWithProot: (COPersistentRoot *)proot
                   store: (COSQLiteStore *)store
{
    COBranch *branch = [proot currentBranch];
    
    //NSLog(@"current branch: %@ has %d commits.g v %@", branch, (int)[[branch allCommits] count], graphView_);
    
    [graphView_ setPersistentRoot: proot branch: branch store: store];
}

- (void) show
{
    [self showWindow: self];
    [self setInspectedDocument: [[NSDocumentController sharedDocumentController]
                                 currentDocument]];
}


- (void) storePersistentRootMetadataDidChange: (NSNotification *)notif
{
    NSLog(@"history window: view did change: %@", notif);
    
    [self updateWithProot: persistentRoot_
                    store: [persistentRoot_ store]];
}

- (void) sliderChanged: (id)sender
{
    NSLog(@"%lf", [sender doubleValue]);
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    
    [self setShouldCascadeWindows: NO];
    [self setWindowFrameAutosaveName: @"pannerWindow"];
    
    [self setDocument: [self document]];
    
} // windowDidLoad

@end
