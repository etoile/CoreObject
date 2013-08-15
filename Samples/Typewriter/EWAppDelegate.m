#import "EWAppDelegate.h"
#import <EtoileFoundation/EtoileFoundation.h>

#import "EWBranchesWindowController.h"
#import "EWHistoryWindowController.h"
#import "EWDocument.h"

@implementation EWAppDelegate

#define STOREURL [NSURL fileURLWithPath: [@"~/typewriterTest.typewriter" stringByExpandingTildeInPath]]

- (id) init
{
    SUPERINIT;
    _store = [[COSQLiteStore alloc] initWithURL: STOREURL];
    _context = [[COEditingContext alloc] initWithStore: _store];

    // Set up application metamodel
    
    ETEntityDescription *docEntity = [[ETEntityDescription alloc] initWithName: @"TypewriterDocument"];
    {
        [docEntity setParent: (id)@"Anonymous.COObject"];
        
        ETPropertyDescription *paragraphsProperty =
        [ETPropertyDescription descriptionWithName: @"paragraphs" type: (id)@"Anonymous.TypewriterParagraph"];
        [paragraphsProperty setPersistent: YES];
        [paragraphsProperty setMultivalued: YES];
        [paragraphsProperty setOrdered: YES];
        
        [docEntity setPropertyDescriptions: A(paragraphsProperty)];
    }
    
    ETEntityDescription *paragraphEntity = [[ETEntityDescription alloc] initWithName: @"TypewriterParagraph"];
    {
        [paragraphEntity setParent: (id)@"Anonymous.COObject"];
        
        ETPropertyDescription *documentProperty =
        [ETPropertyDescription descriptionWithName: @"document" type: (id)@"Anonymous.TypewriterDocument"];
        [documentProperty setIsContainer: YES];
        [documentProperty setMultivalued: NO];
        [documentProperty setOpposite: (id)@"Anonymous.TypewriterDocument.paragraphs"];
        
        ETPropertyDescription *dataProperty =
        [ETPropertyDescription descriptionWithName: @"data" type: (id)@"Anonymous.NSData"];
        [dataProperty setPersistent: YES];
        
        [paragraphEntity setPropertyDescriptions: A(documentProperty, dataProperty)];
    }
    
    [[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: docEntity];
    [[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: paragraphEntity];
    
    [[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
    
    return self;
}

- (void)dealloc
{
    [_store release];
    [_context release];
    [super dealloc];
}

- (COSQLiteStore *) store
{
    return _store;
}

- (COEditingContext *) editingContext
{
    return _context;
}

- (void) applicationDidFinishLaunching: (NSNotification*)notif
{
    [[EWBranchesWindowController sharedController] showWindow: self];
    [[EWHistoryWindowController sharedController] showWindow: self];
    
    for (COPersistentRoot *root in [_context persistentRoots])
    {
        EWDocument *doc = [[[EWDocument alloc] initWithPersistentRoot: root] autorelease];
        [[NSDocumentController sharedDocumentController] addDocument: doc];
        [doc makeWindowControllers];
        [doc showWindows];
        
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
