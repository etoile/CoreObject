#import "OutlineController.h"


@implementation OutlineController

// Hack to recieve notifications when the model is changed.

- (void) setDelegatesOn: (OutlineItem *)i
{
  [i setDelegate: self];
  for (OutlineItem *child in [i contents])
  {
    [self setDelegatesOn: child];
  }
}

- (void) unsetDelegatesOn: (OutlineItem *)i
{
  [i setDelegate: nil];
  for (OutlineItem *child in [i contents])
  {
    [self unsetDelegatesOn: child];
  }  
}

// End hack.


- (id)initWithDocument: (id)document
{
  self = [super initWithWindowNibName: @"OutlineWindow"];
  
  if (!self) { [self release]; return nil; }

  doc = document; // weak ref
  
  assert([self rootObject] != nil);
  
  [self setDelegatesOn: [self rootObject]];
  
  return self;
}

- (void)dealloc
{
  [self unsetDelegatesOn: [self rootObject]];
  [super dealloc];
}

- (Document*)projectDocument
{
  return doc;
}
- (OutlineItem*)rootObject
{
  return [[self projectDocument] rootObject];
} 
- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription;
{
  [[[self rootObject] objectContext] commitWithType:type shortDescription:shortDescription longDescription:longDescription];
}

- (void)windowDidLoad
{
  [outlineView registerForDraggedTypes:
                        [NSArray arrayWithObject:@"org.etoile.outlineItem"]];
  [outlineView setDelegate: self];
}

- (void)windowWillClose:(NSNotification *)notification
{
  NSLog(@"TODO: handle outline closing");
}

static int i = 0;

- (OutlineItem *) newItem
{
  OutlineItem *item = [[OutlineItem alloc] initWithParent: nil
                                                  context: [[self rootObject] objectContext]];
  [item autorelease];
  [item setLabel: [NSString stringWithFormat: @"Item %d", i++]];
  [item setDelegate: self];
  return item;
}

- (OutlineItem *) selectedItem
{
  OutlineItem *dest = [outlineView itemAtRow: [outlineView selectedRow]];
  if (dest == nil) { dest = [self rootObject]; }
  return dest;
}

- (OutlineItem *) selectedItemParent
{
  OutlineItem *dest = [[self selectedItem] parent];
  if (dest == nil) { dest = [self rootObject]; }
  return dest;
}

/* IB Actions */

- (IBAction) addItem: (id)sender;
{
  OutlineItem *dest = [self selectedItemParent];
  OutlineItem *item = [self newItem];
  [dest addItem: item];

  [outlineView expandItem: dest];

  [self commitWithType: kCOTypeMinorEdit
      shortDescription: @"Add Item"
       longDescription: [NSString stringWithFormat: @"Add item..."]];
}

- (IBAction) addChildItem: (id)sender;
{
  OutlineItem *dest = [self selectedItem];

  OutlineItem *item = [self newItem];
  [dest addItem: item];

  [outlineView expandItem: dest];

  [self commitWithType: kCOTypeMinorEdit
      shortDescription: @"Add Child Item"
       longDescription: [NSString stringWithFormat: @"Add child item to %@", [dest label]]];
}

- (IBAction) shiftLeft: (id)sender
{
  OutlineItem *item = [self selectedItem];
  OutlineItem *parent = [item parent];
  OutlineItem *grandparent = [parent parent];
  
  NSInteger indexOfItemInParent = [[parent contents] indexOfObject: item];
  assert(indexOfItemInParent != NSNotFound);
  if (grandparent != nil)
  {
    [item retain];
    [parent removeItemAtIndex: indexOfItemInParent];
    [grandparent addItem: item atIndex: [[grandparent contents] indexOfObject: parent] + 1];
    [item release];
    
    [outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[outlineView rowForItem: item]]
         byExtendingSelection: NO];

    [self commitWithType: kCOTypeMinorEdit
        shortDescription: @"Shift Left"
         longDescription: [NSString stringWithFormat: @"Shift left item %@", [item label]]];
  }
}
- (IBAction) shiftRight: (id)sender
{
  OutlineItem *item = [self selectedItem];
  OutlineItem *parent = [item parent];
  NSInteger indexOfItemInParent = [[parent contents] indexOfObject: item];
  assert(indexOfItemInParent != NSNotFound);
  if (parent != nil && indexOfItemInParent > 0)
  {
    NSLog(@"Requesting object at %d in collection of %d", indexOfItemInParent - 1, [[parent contents] count]);
    OutlineItem *newParent = [[parent contents] objectAtIndex: (indexOfItemInParent - 1)];
    [item retain];
    [parent removeItemAtIndex: [[parent contents] indexOfObject: item]];
    [newParent addItem: item];
    [item release];
    
    [outlineView expandItem: newParent];

    [outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[outlineView rowForItem: item]]
             byExtendingSelection: NO];

    [self commitWithType: kCOTypeMinorEdit
        shortDescription: @"Shift Right"
         longDescription: [NSString stringWithFormat: @"Shift right item %@", [item label]]];
  }  
}

- (IBAction) shareWith: (id)sender
{
  [[[NSApplication sharedApplication] delegate] shareWithInspectorForDocument: doc];
}

/* NSResponder */

- (void)insertTab:(id)sender
{
  [self shiftRight: sender];
}
 
- (void)insertBacktab:(id)sender
{
  [self shiftLeft: sender];
}


/* NSOutlineView data source */

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
  if (nil == item) { item = [self rootObject]; }
  return [[item contents] objectAtIndex: index];
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item
{
  if (nil == item) { item = [self rootObject]; }
  return [[item contents] count] > 0;
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
  if (nil == item) { item = [self rootObject]; }
  return [[item contents] count];
}

- (id) outlineView: (NSOutlineView *)outlineView objectValueForTableColumn: (NSTableColumn *)column byItem: (id)item
{
  if (nil == item) { item = [self rootObject]; }
  return [item label];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  if (nil == item) { item = [self rootObject]; }
  
  NSString *oldLabel = [[item label] retain];
  [item setLabel: object];

  [self commitWithType: kCOTypeMinorEdit
      shortDescription: @"Edit Label"
       longDescription: [NSString stringWithFormat: @"Edit label from %@ to %@", oldLabel, [item label]]];
       
  [oldLabel release];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pb
{
  NSMutableArray *pbItems = [NSMutableArray array];
  
  for (OutlineItem *outlineItem in items)
  {    
    NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
    [item setPropertyList: [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInteger: (NSInteger)outlineItem], @"outlineItemPointer",
                                [NSNumber numberWithInteger: (NSInteger)outlineView], @"outlineViewPointer",
                                nil]
                  forType: @"org.etoile.outlineItem"];
    [pbItems addObject: item];
  }
  
  [pb clearContents];
  return [pb writeObjects: pbItems];
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
  for (NSPasteboardItem *pbItem in [[info draggingPasteboard] pasteboardItems])
  {
    OutlineItem *srcItem = (OutlineItem*)[[[pbItem propertyListForType: @"org.etoile.outlineItem"] valueForKey:@"outlineItemPointer"] integerValue];
    
    // Ensure the destination isn't a child of, or equal to, the source    
    for (OutlineItem *tempDest = item; tempDest != nil; tempDest = [tempDest parent])
    {
      if ([tempDest isEqual: srcItem])
      {
        return NSDragOperationNone;
      }
    }
  }

  return NSDragOperationPrivate;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)newParent childIndex:(NSInteger)index
{
  if (nil == newParent) { newParent = [self rootObject]; }
  
  NSUInteger insertionIndex = index;
  NSLog(@" Drop on to %@ at %d", [newParent label], (int)index);
  
  NSMutableIndexSet *newSelectedRows = [NSMutableIndexSet indexSet];
  NSMutableArray *outlineItems = [NSMutableArray array];

  for (NSPasteboardItem *pbItem in [[info draggingPasteboard] pasteboardItems])
  {
    [outlineItems addObject: (OutlineItem*)[[[pbItem propertyListForType: @"org.etoile.outlineItem"] valueForKey:@"outlineItemPointer"] integerValue]];
  }
  
  // Here we only work on the model.
  
  for (OutlineItem *outlineItem in outlineItems)
  {
    OutlineItem *oldParent = [outlineItem parent];
    NSUInteger oldIndex = [[oldParent contents] indexOfObject: outlineItem];
    
    NSLog(@"Dropping %@ from %@", [outlineItem label], [oldParent label]);
    if (insertionIndex == -1) { insertionIndex = [[newParent contents] count]; }
    
    if (oldParent == newParent && insertionIndex > oldIndex)
    {
      [oldParent removeItemAtIndex: oldIndex];
      [newParent addItem: outlineItem atIndex: insertionIndex-1]; 
    }
    else
    {
      [oldParent removeItemAtIndex: oldIndex];
      [newParent addItem: outlineItem atIndex: insertionIndex++]; 
    }
  }

  [outlineView expandItem: newParent];
  
  for (OutlineItem *outlineItem in outlineItems)
  {
    [newSelectedRows addIndex: [outlineView rowForItem: outlineItem]];
  }  
  [outlineView selectRowIndexes: newSelectedRows byExtendingSelection: NO];

  [self commitWithType: kCOTypeMinorEdit
      shortDescription: @"Drop Items"
       longDescription: [NSString stringWithFormat: @"Drop items..."]];

  return YES;
}

/* OutlineItem delegate */

- (void)outlineItemDidChange: (OutlineItem*)item
{
  /*OutlineItem *parent = [item parent];
  if (parent != nil)
  {
    [outlineView reloadItem: parent];
  }*/
  
  
  if (item == [self rootObject])
  {
    NSLog(@"root didchange");
    [outlineView reloadData];  
  }
  else
  {
    NSLog(@"%@ didchange", [item label]);
    [outlineView reloadItem: item reloadChildren: YES];  
  }
}

@end
