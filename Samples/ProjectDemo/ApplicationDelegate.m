#import "ApplicationDelegate.h"
#import "OutlineItem.h"
#import "TextItem.h"
#import "OutlineController.h"
#import "DrawingController.h"
#import "TextController.h"
#import "Document.h"
#import "SKTDrawDocument.h"
#import "Project.h"
#import <CoreObject/CoreObject.h>
#import <CoreObject/COPersistentRoot+Private.h>

@implementation ApplicationDelegate

+ (void)initialize
{
    if (self == [ApplicationDelegate class])
    {
        NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                                   NSUserDomainMask,
                                                                   YES);

        NSString *dir = [[libraryDirs[0]
            stringByAppendingPathComponent: @"CoreObject"]
            stringByAppendingPathComponent: @"ProjectDemo.coreobjectstore"];

        [[NSUserDefaults standardUserDefaults] registerDefaults:
            @{@"storeURL": dir}];
    }
}

- (NSURL *)storeURL
{
    return [[NSUserDefaults standardUserDefaults] URLForKey: @"storeURL"];
}

- (void)globalForward: (id)sender
{
    NSLog(@"Forward");
}

- (void)globalBack: (id)sender
{
    NSLog(@"Back");
}

- (void)addStatusBarButtons
{
    NSStatusBar *bar = [NSStatusBar systemStatusBar];

    NSStatusItem *forwardButton = [bar statusItemWithLength: NSSquareStatusItemLength];
    [forwardButton setImage: [NSImage imageNamed: NSImageNameGoRightTemplate]];
    [forwardButton setHighlightMode: YES];
    [forwardButton setTarget: self];
    [forwardButton setAction: @selector(globalForward:)];

    NSStatusItem *backButton = [bar statusItemWithLength: NSSquareStatusItemLength];
    [backButton setImage: [NSImage imageNamed: NSImageNameGoLeftTemplate]];
    [backButton setHighlightMode: YES];
    [backButton setTarget: self];
    [backButton setAction: @selector(globalBack:)];
}

- (NSSet *)projects
{
    NSSet *projects = [[[context persistentRoots]
        mappedCollectionWithBlock: ^(id obj)
        {
            return [obj rootObject];
        }] filteredCollectionWithBlock: ^(id obj)
    {
        return [[[obj entityDescription] name] isEqualToString: @"Project"];
    }];
    return projects;
}

- (void)awakeFromNib
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"clearStore"])
    {
        [[[COSQLiteStore alloc] initWithURL: [self storeURL]] clearStore];
        [[COUndoTrack trackForPattern: @"org.etoile.projectdemo*"
                   withEditingContext: [COEditingContext contextWithURL: [self storeURL]]] clear];
    }

    context = [COEditingContext contextWithURL: [self storeURL]];

    // TODO: Use NSUserDefaults to remember open documents
    //ETUUID *uuid = [[NSUserDefaults standardUserDefaults] UUIDForKey: @"projectDemoProjectUUID"];


    NSSet *projects = [self projects];

    if (![projects isEmpty])
    {
        NSLog(@"Loaded projects: %@", projects);
    }
    else
    {
        COPersistentRoot *proot = [context insertNewPersistentRootWithEntityName: @"Anonymous.Project"];
        [(OutlineItem *)[proot rootObject] setName: @"Untitled project"];
        [context commit];

        NSLog(@"Creating a new project %@", [proot UUID]);
    }

    controllerForWindowID = [[NSMutableDictionary alloc] init];

    //[historyController setContext: context];

    // UI Setup
    [self addStatusBarButtons];

    projects = [self projects];
    for (Project *project in projects)
    {
        // Show existing documents
        for (Document *document in project.documents)
        {
            [self openDocumentWindowForPersistentRoot: document.persistentRoot];
        }
    }
}

- (COEditingContext *)editingContext
{
    return context;
}

- (COSQLiteStore *)store
{
    return [context store];
}

#pragma mark Untitled document name

- (NSString *)untitledDocumentNameForIndex: (NSUInteger)index
{
    return [NSString stringWithFormat: @"Untitled %d", (int)index];
}

- (BOOL)isDocumentNameInUse: (NSString *)aName
{
    for (COPersistentRoot *persistentRoot in context.persistentRoots)
    {
        if ([persistentRoot.name isEqualToString: aName])
            return YES;
    }
    return NO;
}

/**
 * Returns a document name like "Untitled 1" that is not currently in use
 * for a document in context
 */
- (NSString *)untitledDocumentName
{
    NSUInteger i = 1;
    while ([self isDocumentNameInUse: [self untitledDocumentNameForIndex: i]])
    {
        i++;
    }
    return [self untitledDocumentNameForIndex: i];
}

#pragma mark New document

- (void)newDocumentWithType: (NSString *)type rootObjectEntity: (NSString *)rootObjEntity
{
    COPersistentRoot *persistentRoot = [context insertNewPersistentRootWithEntityName: @"Anonymous.Document"];
    assert(persistentRoot != nil);

    persistentRoot.name = [self untitledDocumentName];

    persistentRoot.currentBranch.label = @"Initial Branch";

    ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
    ETEntityDescription *desc = [repo descriptionForName: rootObjEntity];
    COObject *rootObj = [[[repo classForEntityDescription: desc] alloc] initWithEntityDescription: desc
                                                                               objectGraphContext: [persistentRoot objectGraphContext]];

    Document *document = [persistentRoot rootObject];
    [document setRootDocObject: rootObj];
    assert([document rootDocObject] == rootObj);
    [document setDocumentType: type];

    [self registerDocumentRootObject: document];
}

- (IBAction) newWindow: (id)sender
{
    id wc = [[NSApp mainWindow] windowController];
    if (wc != nil && [wc respondsToSelector: @selector(projectDocument)])
    {
        EWDocumentWindowController *docWC = wc;

        NSString *windowID = [[ETUUID UUID] stringValue];

        EWDocumentWindowController *controller = [[[docWC class] alloc] initPinnedToBranch: docWC.editingBranch
                                                                                  windowID: windowID];
        controllerForWindowID[windowID] = controller;
        [controller showWindow: nil];
    }
}

- (IBAction) duplicate: (id)sender
{
    id wcObject = [[NSApp mainWindow] windowController];
    if (wcObject != nil && [wcObject respondsToSelector: @selector(projectDocument)])
    {
        EWDocumentWindowController *wc = wcObject;

        COPersistentRoot *persistentRoot = [[wc editingBranch] makePersistentRootCopy];
        assert(persistentRoot != nil);

        NSString *oldDocName = wc.persistentRoot.name;
        persistentRoot.name = [NSString stringWithFormat: @"Copy of %@", oldDocName];
        persistentRoot.currentBranch.label = @"Initial Branch";

        Document *doc = persistentRoot.rootObject;
        [self registerDocumentRootObject: doc];
    }
}

- (IBAction) reattachAsBranch: (id)sender
{
    id wcObject = [[NSApp mainWindow] windowController];
    if (wcObject != nil && [wcObject respondsToSelector: @selector(projectDocument)])
    {
        EWDocumentWindowController *wc = wcObject;
        COPersistentRoot *proot = wc.persistentRoot;

        [wc close];
        [controllerForWindowID removeObjectForKey: wc.windowID];

        ETAssert(proot.isCopy);

        COPersistentRoot *parent = proot.parentPersistentRoot;
        // FIXME: This is a private method. The ability to create a branch at an arbitrary
        // revision should probably be exposed by COPersistentRoot
        COBranch *reattachedBranch = [parent makeBranchWithLabel: proot.name
                                                      atRevision: proot.currentRevision
                                                    parentBranch: nil];

        proot.deleted = YES;

        [context commit];
        [self controllerForPersistentRoot: parent].pinnedBranch = reattachedBranch;
    }
}

- (BOOL)validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>)anItem
{
    SEL theAction = [anItem action];

    EWDocumentWindowController *wc = nil;
    COPersistentRoot *proot = nil;

    id wcObject = [[NSApp mainWindow] windowController];
    if (wcObject != nil && [wcObject respondsToSelector: @selector(projectDocument)])
    {
        wc = wcObject;
        proot = wc.persistentRoot;
    }

    if (theAction == @selector(reattachAsBranch:))
    {
        return proot.isCopy;
    }

    return [self respondsToSelector: theAction];;
}

- (EWDocumentWindowController *)makeWindowControllerForDocumentRootObject: (Document *)aDoc
{
    ETAssert([aDoc isKindOfClass: [Document class]]);

    NSString *windowID = [[[aDoc persistentRoot] UUID] stringValue];
    ETAssert(controllerForWindowID[windowID] == nil);

    NSDictionary *windowControllerClassForRootDocObjectClassName =
        @{NSStringFromClass([OutlineItem class]): [OutlineController class],
          NSStringFromClass([SKTDrawDocument class]): [DrawingController class],
          NSStringFromClass([TextItem class]): [TextController class]};

    NSString *rootDocObjectClassName = NSStringFromClass([aDoc.rootDocObject class]);
    Class wcClass = windowControllerClassForRootDocObjectClassName[rootDocObjectClassName];
    ETAssert([wcClass isSubclassOfClass: [EWDocumentWindowController class]]);

    EWDocumentWindowController *controller = [[wcClass alloc] initAsPrimaryWindowForPersistentRoot: aDoc.persistentRoot
                                                                                          windowID: windowID];
    [controller showWindow: nil];

    controllerForWindowID[windowID] = controller;
    return controller;
}

- (EWDocumentWindowController *)registerDocumentRootObject: (Document *)aDoc
{
    // FIXME: Total hack
    Project *proj = [[self projects] anyObject];
    [proj addDocument_hack: aDoc];

    NSLog(@"Added a document model object %@", aDoc);

    [context commit];

    [newDocumentTypeWindow orderOut: nil];

    EWDocumentWindowController *controller = [self makeWindowControllerForDocumentRootObject: aDoc];
    return controller;
}

- (IBAction) newTextDocument: (id)sender
{
    [self newDocumentWithType: @"text" rootObjectEntity: @"TextItem"];
}

- (IBAction) newOutline: (id)sender
{
    [self newDocumentWithType: @"outline" rootObjectEntity: @"OutlineItem"];
}

- (IBAction) newDrawing: (id)sender
{
    [self newDocumentWithType: @"drawing" rootObjectEntity: @"SKTDrawDocument"];
}

/* Convenience */

- (NSWindowController *)keyDocumentController
{
    for (NSWindowController *controller in [controllerForWindowID allValues])
    {
        if ([[controller window] isKeyWindow])
        {
            return controller;
        }
    }
    return nil;
}

- (Document *)keyDocument
{
    return [(OutlineController *)[self keyDocumentController] projectDocument];
}

/* NSResponder */

- (void)saveDocument: (id)sender
{
    [self checkpointWithName: nil];
}

- (void)saveDocumentAs: (id)sender
{
    NSString *name = [checkpointAsSheetController showSheet];
    if (name != nil)
    {
        [self checkpointWithName: name];
    }
}

- (void)checkpointWithName: (NSString *)name
{
    if ([name length] == 0)
    {
        name = @"Untitled Checkpoint";
    }

//    [[[doc objectGraphContext] editingContext] commit];
//    
//  [context commitWithType: kCOTypeCheckpoint
//         shortDescription: @"Checkpoint"
//          longDescription: name];
    [context commit];
}

- (IBAction)newProject: (id)sender
{
//  Project *newProject = [[Project alloc] initWithObjectGraphContext: context];
//  [context commit];
//  NSLog(@"Creating a new project %@ = %@", [newProject uuid], newProject); 
//  [newProject setDelegate: self];
//
//  
}

- (IBAction)deleteProject: (id)sender
{


}


- (EWDocumentWindowController *)controllerForDocumentRootObject: (COObject *)rootObject
{
    for (EWDocumentWindowController *controller in [controllerForWindowID allValues])
    {
        if ([[controller documentObject] isEqual: rootObject])
        {
            return controller;
        }
    }

//  for (Project *project in [self projects])
//  {
//      for (Document *doc in [project documents])
//      {
//          if ([[[doc rootObject] UUID] isEqual: [rootObject UUID]])
//          {
//              return [controllerForDocumentUUID objectForKey: [doc UUID]];
//          }
//      }
//  }
    return nil;
}

- (EWDocumentWindowController *)controllerForPersistentRoot: (COPersistentRoot *)persistentRoot
{
    return [self controllerForDocumentRootObject: [persistentRoot rootObject]];
}

- (void)openDocumentWindowForPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    EWDocumentWindowController *wc = [self controllerForPersistentRoot: aPersistentRoot];
    if (wc == nil)
    {
        wc = [self makeWindowControllerForDocumentRootObject: [aPersistentRoot rootObject]];
    }
    [wc showWindow: nil];
}

/* Project delegate */

//- (void)keyDocumentChanged: (NSNotification*)notif
//{
//  //NSLog(@"Key document changed to: %@", [self keyDocumentController]);
//  
//  [tagWindowController setDocument: [self keyDocument]];
//  
//  // FIXME: update inspectors 
//}

- (void)projectDocumentsDidChange: (Project *)p
{
//  NSLog(@"projectDocumentsDidChange: called, loading %d documents", (int)[[p documents] count]);
//  
//  static NSDictionary *classForType;
//  if (classForType == nil)
//  {
//      classForType = [[NSDictionary alloc] initWithObjectsAndKeys:
//          [OutlineController class], @"outline",
//          [DrawingController class], @"drawing",
//          [TextController class], @"text",
//          nil];
//  }
//  
//  NSMutableSet *unwantedDocumentUUIDs = [NSMutableSet setWithArray:
//                                         [controllerForDocumentUUID allKeys]];
//  
//  for (Document *doc in [p documents])
//  {
//      [unwantedDocumentUUIDs removeObject: [doc UUID]];
//      
//      OutlineController *controller = [controllerForDocumentUUID objectForKey: [doc UUID]];
//      if (controller == nil)
//      {
//          Class cls = [classForType objectForKey: [doc documentType]];
//          assert(cls != Nil);
//          
//          // Create a new document controller
//          controller = [[cls alloc] initWithDocument: doc];
//          [controller showWindow: nil];
//          [controllerForDocumentUUID setObject: controller forKey: [doc UUID]];
//          // Observe key document changes
//          [[NSNotificationCenter defaultCenter] addObserver: self
//                                                   selector: @selector(keyDocumentChanged:)
//                                                       name: NSWindowDidBecomeKeyNotification
//                                                     object: [controller window]];
//      }
//  }
//  
//  for (ETUUID *unwanted in unwantedDocumentUUIDs)
//  {
//      NSWindow *window = [[controllerForDocumentUUID objectForKey: unwanted] window];
//      [[NSNotificationCenter defaultCenter] removeObserver: self
//                                                      name: NSWindowDidBecomeKeyNotification
//                                                    object: window];
//      [window orderOut: nil];
//      [controllerForDocumentUUID removeObjectForKey: unwanted];
//  }
}

- (void)shareWithInspectorForDocument: (Document *)doc
{
    NSLog(@"Share %@", doc);
}

- (void)showSearchResults: (id)sender
{
    [searchWindow orderFront: self];
}

@end
