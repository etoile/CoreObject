#import "EWHistoryWindowController.h"
#import "EWDocument.h"
#import <CoreObject/CoreObject.h>

@implementation EWHistoryWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"History"];
    if (self) {
        
//        [[NSNotificationCenter defaultCenter] addObserver: self
//                                                 selector: @selector(storePersistentRootMetadataDidChange:)
//                                                     name: COStorePersistentRootMetadataDidChangeNotification
//                                                   object: nil];
    }
    return self;
}

- (void) dealloc
{
//    [[NSNotificationCenter defaultCenter] removeObserver: self
//                                                    name: COStorePersistentRootMetadataDidChangeNotification
//                                                  object: nil];
    
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
    
    [self updateWithProot:[(EWDocument *)aDoc currentPersistentRoot]
                    store:[(EWDocument *)aDoc store]];
}

- (void) updateWithProot: (COPersistentRootInfo *)proot
                   store: (COSQLiteStore *)store
{
    COBranch *branch = [proot currentBranch];
    
    NSLog(@"current branch: %@ has %d commits.g v %@", branch, (int)[[branch allCommits] count], graphView_);
    
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
    
//    COSQLiteStore *store = [notif object];
//    ETUUID *aUUID = [[notif userInfo] objectForKey: COStoreNotificationUUID];
//    COPersistentRootInfo *proot = [store persistentRootWithUUID: aUUID];
//    
//    [self updateWithProot: proot store: store];
}

- (void) sliderChanged: (id)sender
{
    NSLog(@"%lf", [sender doubleValue]);
}

@end
