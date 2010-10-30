#import "ApplicationDelegate.h"
#import "OutlineItem.h"
#import "OutlineController.h"
#import "Document.h"
#import "HistoryInspectorController.h"
#import "SharingServer.h"

#define STORE_URL [NSURL URLWithString: [@"~/ProjectDemoStore" stringByExpandingTildeInPath]]

@implementation ApplicationDelegate

- (void)awakeFromNib
{
  context = [[COEditingContext alloc] initWithStoreCoordinator: 
    [[[COStoreCoordinator alloc] initWithURL: STORE_URL] autorelease]];
  
  ETUUID *uuid = [[NSUserDefaults standardUserDefaults] UUIDForKey: @"projectDemoProjectUUID"];
  
  Project *loaded = [context objectForUUID: uuid];
  NSLog(@"Got UUID %@ from user defaults. The context returns: %@", uuid, loaded);
  
  if (nil != uuid && nil != loaded)
  {
    ASSIGN(project, (Project*)[context objectForUUID: uuid]);
    NSLog(@"Loading existing project %@ = %@", uuid, project);
    NSLog(@"It has %@ documents", [project documents]);
  }
  else
  {
    project = [[Project alloc] initWithContext: context];
    [context commit];
    NSLog(@"Creating a new project %@ = %@", [project uuid], project); 
    [[NSUserDefaults standardUserDefaults] setUUID: [project uuid]
                                            forKey: @"projectDemoProjectUUID"];
  }
  
  [project setDelegate: self];
  
  controllerForDocumentUUID = [[NSMutableDictionary alloc] init];
  
  [historyController setContext: context];
  
  // Show existing documents
  [self projectDocumentsDidChange: project];
}

- (COEditingContext*)editingContext
{
  return context;
}

- (void)dealloc
{
  [project release];
  [controllerForDocumentUUID release];
  [super dealloc];
}

- (IBAction) newTextDocument: (id)sender
{

}
- (IBAction) newOutline: (id)sender
{
  OutlineItem *outlineItem = [[[OutlineItem alloc] initWithContext: context] autorelease];
  
  Document *document = [[[Document alloc] initWithContext: context] autorelease];
  [document setRootObject: outlineItem];
  [document setDocumentName: [NSString stringWithFormat: @"Document %@", [[document uuid] stringValue]]];
  
  [project addDocument: document];

  NSLog(@"Added a document model object %@, outline item %@", document, outlineItem);
  NSLog(@"Changed objects %@", [context changedObjects]);
  [context commit];

  [newDocumentTypeWindow orderOut: nil];
}
- (IBAction) newDrawing: (id)sender
{

}

/* Convenience */

- (NSWindowController*) keyDocumentController
{
  for (NSWindowController *controller in [controllerForDocumentUUID allValues])
  {
    if ([[controller window] isKeyWindow])
    {
      return controller;
    }
  }
  return nil;
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

- (void)checkpointWithName: (NSString*)name
{
  if ([name length] == 0)
  {
    name = @"Untitled Checkpoint";
  }
  [context commitWithType: kCOTypeCheckpoint
    shortDescription: @"Checkpoint"
     longDescription: name];
}

/* Project delegate */

- (void)projectDocumentsDidChange: (Project*)p
{
  NSLog(@"projectDocumentsDidChange: called, loading %d documents", (int)[[p documents] count]);
  
  NSMutableSet *unwantedDocumentUUIDs = [NSMutableSet setWithArray:
    [controllerForDocumentUUID allKeys]];
  
  for (Document *doc in [p documents])
  {
    [unwantedDocumentUUIDs removeObject: [doc uuid]];
   
    OutlineController *controller = [controllerForDocumentUUID objectForKey: [doc uuid]];
    if (controller == nil)
    {
      // Create a new document controller
      controller = [[[OutlineController alloc] initWithDocument: doc] autorelease];
      [controller showWindow: nil];
      [controllerForDocumentUUID setObject: controller forKey: [doc uuid]];
    }
  }
  
  for (ETUUID *unwanted in unwantedDocumentUUIDs)
  {
    NSWindow *window = [[controllerForDocumentUUID objectForKey: unwanted] window];
    [window orderOut: nil];
    [controllerForDocumentUUID removeObjectForKey: unwanted];
  }
}

- (void) shareWithInspectorForDocument: (Document*)doc
{
  [sharingController shareWithInspectorForDocument: doc];
}

@end
