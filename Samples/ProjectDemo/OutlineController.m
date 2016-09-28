#import "OutlineController.h"
#import "ItemReference.h"
#import "Document.h"
#import "ApplicationDelegate.h"
#import <CoreObject/COSQLiteStore+Graphviz.h>
#import "EWOutlineView.h"

@implementation OutlineController

- (instancetype)initAsPrimaryWindowForPersistentRoot: (COPersistentRoot *)aPersistentRoot
                                            windowID: (NSString *)windowID
{
    self = [super initAsPrimaryWindowForPersistentRoot: aPersistentRoot
                                              windowID: windowID
                                         windowNibName: @"OutlineWindow"];
    return self;
}

- (instancetype)initPinnedToBranch: (COBranch *)aBranch
                          windowID: (NSString *)windowID
{
    self = [super initPinnedToBranch: aBranch
                            windowID: windowID
                       windowNibName: @"OutlineWindow"];
    return self;
}

- (void)reloadOutlineView
{
    @try
    {
        // Reloading the outline view could cause a commit (e.g., a field editor ends editing).
        // Block the commit from happening.
        preventCommits = YES;

        [outlineView reloadData];

    }
    @finally
    {
        preventCommits = NO;
    }
}

- (void)objectGraphDidChange
{
    // FIXME: Merge this and the next method!

    //NSLog(@"Reloading outline for %@", doc);
    [self reloadOutlineView];
}

- (void)objectGraphContextDidChange: (NSNotification *)notif
{
    // FIXME: Merge this and the previous method!

    NSLog(@"object graph context did change: %@", [notif userInfo]);

    [self reloadOutlineView];

    for (ETUUID *updated in notif.userInfo[COUpdatedObjectsKey])
    {
        COObject *updatedObject = [self.objectGraphContext loadedObjectForUUID: updated];
        [outlineView expandItem: updatedObject];
    }
}

- (Document *)projectDocument
{
    return [self.objectGraphContext rootObject];
}

- (OutlineItem *)rootObject
{
    return (OutlineItem *)[[self projectDocument] rootDocObject];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [outlineView registerForDraggedTypes:
        @[@"org.etoile.outlineItem", @"public.file-url"]];
    [outlineView setDelegate: self];
    [outlineView setTarget: self];
    [outlineView setDoubleAction: @selector(doubleClick:)];
    outlineView.delegate = self;

    //NSLog(@"Got rect %@ for doc %@", NSStringFromRect([doc screenRectValue]), [doc uuid]);

//  if (!NSIsEmptyRect([doc screenRect]))
//  {
//      // Disable automatic positioning
//      [self setShouldCascadeWindows: NO];
//      [[self window] setFrame: [doc screenRect] display: NO];
//  }


//  [[NSNotificationCenter defaultCenter] addObserver: self
//                                           selector: @selector(windowFrameDidChange:)
//                                               name: NSWindowDidMoveNotification 
//                                             object: [self window]];
//  
//  [[NSNotificationCenter defaultCenter] addObserver: self
//                                           selector: @selector(windowFrameDidChange:)
//                                               name: NSWindowDidEndLiveResizeNotification 
//                                             object: [self window]];  
//  
}

- (void)windowFrameDidChange: (NSNotification *)notification
{
    // This was rather annoying so I disabled it
//  [doc setScreenRect: [[self window] frame]];
//  
////    assert([[doc objectGraphContext] objectHasChanges: [doc UUID]]);
//  
//  [self commitWithType: @"kCOTypeMinorEdit"
//      shortDescription: @"Move Window"
//       longDescription: [NSString stringWithFormat: @"Move to %@", NSStringFromRect([doc screenRect])]];  
}

- (void)windowWillClose: (NSNotification *)notification
{
    NSLog(@"TODO: handle outline closing");
}

static int i = 0;

- (OutlineItem *)newItem
{
    OutlineItem *item = [[OutlineItem alloc]
        initWithObjectGraphContext: [[self rootObject] objectGraphContext]];

    [item setLabel: [NSString stringWithFormat: @"Item %d", i++]];
    return item;
}

- (OutlineItem *)selectedItem
{
    OutlineItem *dest = [outlineView itemAtRow: [outlineView selectedRow]];
    if (dest == nil)
    { dest = [self rootObject]; }
    return dest;
}

- (OutlineItem *)selectedItemParent
{
    OutlineItem *dest = [[self selectedItem] parent];
    if (dest == nil)
    { dest = [self rootObject]; }
    return dest;
}

/* IB Actions */

- (IBAction) addItem: (id)sender;
{
    OutlineItem *dest = [self selectedItemParent];
    OutlineItem *item = [self newItem];
    [dest addItem: item];

    [self commitWithIdentifier: @"add-item" descriptionArguments: @[item.label]];

    [outlineView expandItem: dest];
}

- (IBAction) addChildItem: (id)sender;
{
    OutlineItem *dest = [self selectedItem];

    if ([dest isKindOfClass: [OutlineItem class]])
    {
        OutlineItem *item = [self newItem];
        [dest addItem: item];

        [self commitWithIdentifier: @"add-child-item"
              descriptionArguments: @[item.label, dest.label]];

        // Needs to be after the outline view reloads its data; the outline view won't expand an item
        // it thinks is a leaf.
        [outlineView expandItem: dest];
    }
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
        [parent removeItemAtIndex: indexOfItemInParent];
        [grandparent addItem: item atIndex: [[grandparent contents] indexOfObject: parent] + 1];

        [self commitWithIdentifier: @"shift-left" descriptionArguments: @[item.label]];

        [outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: [outlineView rowForItem: item]]
                 byExtendingSelection: NO];
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
        NSLog(@"Requesting object at %d in collection of %d",
              (int)(indexOfItemInParent - 1), (int)[[parent contents] count]);
        OutlineItem *newParent = [[parent contents] objectAtIndex: (indexOfItemInParent - 1)];

        if ([newParent isKindOfClass: [OutlineItem class]])
        {

            [parent removeItemAtIndex: [[parent contents] indexOfObject: item]];
            [newParent addItem: item];

            [self commitWithIdentifier: @"shift-right" descriptionArguments: @[item.label]];

            [outlineView expandItem: newParent];

            [outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: [outlineView rowForItem: item]]
                     byExtendingSelection: NO];
        }
    }
}

/* NSResponder */

- (void)insertTab: (id)sender
{
    [self shiftRight: sender];
}

- (void)insertBacktab: (id)sender
{
    [self shiftLeft: sender];
}

static NSString *implode(NSArray *array, NSString *separator)
{
    NSMutableString *result = [NSMutableString new];
    const NSUInteger count = [array count];
    for (NSUInteger i = 0; i < count; i++)
    {
        [result appendString: [array[i] description]];
        if (i + 1 < count)
        {
            [result appendString: separator];
        }
    }
    return result;
}

- (void)deleteForward: (id)sender
{
    NSArray *selectedRows = [self selectedRows];
    if ([selectedRows count] == 0)
        return;

    NSString *label = implode((NSArray *)[[selectedRows mappedCollection] label], @", ");

    for (OutlineItem *item in selectedRows)
    {
        if (item == [self rootObject])
            continue;

        NSInteger index = [[[item parent] contents] indexOfObject: item];
        assert(index != NSNotFound);
        [[item parent] removeItemAtIndex: index];
    }

    [self commitWithIdentifier: @"delete" descriptionArguments: @[label]];
}

- (void)delete: (id)sender
{
    [self deleteForward: sender];
}

- (void)keyDown: (NSEvent *)theEvent
{
    [self interpretKeyEvents: [NSArray arrayWithObject: theEvent]];
}

/* NSOutlineView Target/Action */

- (void)doubleClick: (id)sender
{
    if (sender == outlineView)
    {
        id item = [self selectedItem];
        if ([item isKindOfClass: [ItemReference class]])
        {
            // User double clicked on an item reference / link
            // so order-front the link target's document window and select it.
            id target = [item referencedItem];

            id root = [target root];
            OutlineController *otherController = (OutlineController *)[(ApplicationDelegate *)[[NSApplication sharedApplication] delegate]
                controllerForDocumentRootObject: root];
            assert(otherController != nil);

            // FIXME: ugly

            [[otherController window] makeKeyAndOrderFront: nil];
            [otherController->outlineView expandItem: nil expandChildren: YES];
            [otherController->outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: [otherController->outlineView rowForItem: target]]
                                      byExtendingSelection: NO];
        }
        else if ([item isKindOfClass: [OutlineItem class]])
        {
            if (((OutlineItem *)item).attachmentID != nil)
            {
                COAttachmentID *attachmentID = ((OutlineItem *)item).attachmentID;
                NSURL *attachmentPrivateURL = [[[self persistentRoot] store] URLForAttachmentID: attachmentID];

                NSURL *tempURL = [NSURL fileURLWithPath: [NSTemporaryDirectory() stringByAppendingPathComponent: [item label]]];

                [[NSFileManager defaultManager] removeItemAtURL: tempURL error: NULL];

                if ([[NSFileManager defaultManager] copyItemAtURL: attachmentPrivateURL
                                                            toURL: tempURL
                                                            error: NULL])
                {
                    [[NSWorkspace sharedWorkspace] openURL: tempURL];
                }
                else
                {
                    NSLog(@"Failed to open attachment '%@'. The file %@ probably does not exist in the store.",
                          [item label], [attachmentPrivateURL path]);
                }
            }
            else
            {
                // setting a double action on an outline view seems to break normal editing
                // so we hack it in here.

                [outlineView editColumn: 0
                                    row: [outlineView selectedRow]
                              withEvent: nil
                                 select: YES];
            }
        }
    }
}

/* NSOutlineView delegate */

- (BOOL)  outlineView: (NSOutlineView *)outlineView
shouldEditTableColumn: (NSTableColumn *)tableColumn
                 item: (id)item
{
    if ([item isKindOfClass: [OutlineItem class]])
    {
        return YES;
    }
    return NO;
}

/* NSOutlineView data source */

- (id)outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
    if (nil == item)
    { item = [self rootObject]; }

    NSArray *contents = [item contents];

    // Sometime NSOutlineView (OS X 10.9) is buggy and asks for non-existent children
    // (e.g. Two outline items:
    //   - A
    //   - B
    //  With the field editor open, rename B, and click 'shift right' before closing the field editor)
    if (index >= [contents count])
        return nil;

    return [contents objectAtIndex: index];
}

- (BOOL)outlineView: (NSOutlineView *)ov isItemExpandable: (id)item
{
    return [self outlineView: ov numberOfChildrenOfItem: item] > 0;
}

- (NSInteger)outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
    if (nil == item)
    { item = [self rootObject]; }
    if ([item isKindOfClass: [OutlineItem class]])
    {
        return [[item contents] count];
    }
    else
    {
        return 0;
    }
}

- (id)        outlineView: (NSOutlineView *)outlineView
objectValueForTableColumn: (NSTableColumn *)column
                   byItem: (id)item
{
    if (nil == item)
    { item = [self rootObject]; }
    return [item label];
}

- (void)outlineView: (NSOutlineView *)outlineView
     setObjectValue: (id)object
     forTableColumn: (NSTableColumn *)tableColumn
             byItem: (id)item
{
    if (preventCommits)
        return;

    if (nil == item)
    { item = [self rootObject]; }

    if ([item isKindOfClass: [OutlineItem class]])
    {
        NSString *oldLabel = [item label];
        [item setLabel: object];

        [self commitWithIdentifier: @"rename" descriptionArguments: @[oldLabel, object]];
    }
}

- (BOOL)outlineView: (NSOutlineView *)outlineView
         writeItems: (NSArray *)items
       toPasteboard: (NSPasteboard *)pb
{
    NSMutableArray *pbItems = [NSMutableArray array];

    for (OutlineItem *outlineItem in items)
    {
        NSPasteboardItem *item = [[NSPasteboardItem alloc] init];

        [item setPropertyList: [self pasteboardPropertyListForOutlineItem: outlineItem]
                      forType: @"org.etoile.outlineItem"];
        [pbItems addObject: item];
    }

    [pb clearContents];
    return [pb writeObjects: pbItems];
}

- (NSArray *)selectedRows
{
    NSMutableArray *result = [NSMutableArray array];

    NSIndexSet *selIndexes = [outlineView selectedRowIndexes];

    for (NSUInteger i = [selIndexes firstIndex]; i != NSNotFound; i = [selIndexes indexGreaterThanIndex: i])
    {
        [result addObject: [outlineView itemAtRow: i]];
    }

    return [NSArray arrayWithArray: result];
}

#pragma mark cut / copy / paste

- (IBAction)copy: (id)sender
{
    NSArray *rows = [self selectedRows];

    if ([rows count] == 0)
    {
        NSLog(@"Nothing to copy");
        return;
    }

    [self outlineView: outlineView writeItems: rows toPasteboard: [NSPasteboard generalPasteboard]];
}

- (IBAction)paste: (id)sender
{
    NSLog(@"Paste!");

    // test paste destination

    NSArray *rows = [self selectedRows];

    OutlineItem *parent;
    NSUInteger index;

    if ([rows count] == 0)
    {
        parent = nil;
        index = [[[self rootObject] contents] count];
    }
    else
    {
        OutlineItem *item = rows[0];
        parent = [item parent];
        index = [[parent contents] indexOfObject: item] + 1;
    }

    [self pasteFromPasteboard: [NSPasteboard generalPasteboard]
                       atItem: parent
                   childIndex: index
                    pasteLink: NO
                    pasteCopy: YES];
}

- (IBAction)cut: (id)sender
{
    [self copy: sender];
    [self delete: sender];
}

#pragma mark drag & drop

- (id)pasteboardPropertyListForOutlineItem: (OutlineItem *)outlineItem
{
    return @{@"persistentRoot": [[[outlineItem persistentRoot] UUID] stringValue],
             @"branch": [[[outlineItem branch] UUID] stringValue],
             @"usesMainObjectGraph": @([outlineItem objectGraphContext] == [[outlineItem persistentRoot] objectGraphContext]),
             @"uuid": [[outlineItem UUID] stringValue]};
}

- (OutlineItem *)outlineItemForPasteboardPropertyList: (id)plist
{
    ETUUID *persistentRootUUID = [ETUUID UUIDWithString: plist[@"persistentRoot"]];
    ETUUID *branchUUID = [ETUUID UUIDWithString: plist[@"branch"]];
    ETUUID *objectUUID = [ETUUID UUIDWithString: plist[@"uuid"]];
    BOOL usesMainObjectGraph = [plist[@"usesMainObjectGraph"] boolValue];

    COPersistentRoot *persistentRoot = [self.editingContext persistentRootForUUID: persistentRootUUID];
    ETAssert(persistentRoot != nil);

    COBranch *branch = [persistentRoot branchForUUID: branchUUID];

    COObjectGraphContext *objectGraph;

    // This is to ensure we don't modify both [persistentRoot objectGraphContext] and
    // [branch objectGraphContext]
    if (branch == self.editingBranch)
    {
        objectGraph = self.objectGraphContext;
    }
    else
    {
        objectGraph = usesMainObjectGraph ? [persistentRoot objectGraphContext] : [[persistentRoot branchForUUID: branchUUID] objectGraphContext];
    }

    ETAssert(objectGraph != nil);

    OutlineItem *result = (OutlineItem *)[objectGraph loadedObjectForUUID: objectUUID];
    ETAssert(result != nil);

    return result;
}

- (NSDragOperation)outlineView: (NSOutlineView *)outlineView
                  validateDrop: (id <NSDraggingInfo>)info
                  proposedItem: (id)item
            proposedChildIndex: (NSInteger)index
{
    if (item != nil && ![item isKindOfClass: [OutlineItem class]])
    {
        return NSDragOperationNone;
    }

    // Ensure the destination isn't a child of, or equal to, the source

    for (NSPasteboardItem *pbItem in [[info draggingPasteboard] pasteboardItems])
    {
        id plist = [pbItem propertyListForType: @"org.etoile.outlineItem"];
        if (plist == nil)
            continue;

        OutlineItem *srcItem = [self outlineItemForPasteboardPropertyList: plist];

        for (OutlineItem *tempDest = item; tempDest != nil; tempDest = [tempDest parent])
        {
            if ([tempDest isEqual: srcItem])
            {
                return NSDragOperationNone;
            }
        }
    }

    if ([info draggingSourceOperationMask] & NSDragOperationCopy)
        return NSDragOperationCopy;

    if ([info draggingSourceOperationMask] & NSDragOperationLink)
        return NSDragOperationLink;

    return NSDragOperationMove;
}

- (BOOL)outlineView: (NSOutlineView *)outlineView
         acceptDrop: (id <NSDraggingInfo>)info
               item: (id)newParent
         childIndex: (NSInteger)index
{
    NSLog(@"Dragging mask: %d", (int)[info draggingSourceOperationMask]);

    return [self pasteFromPasteboard: [info draggingPasteboard]
                              atItem: newParent
                          childIndex: index
                           pasteLink: [info draggingSourceOperationMask] == NSDragOperationLink
                           pasteCopy: [info draggingSourceOperationMask] == NSDragOperationCopy];
}

- (NSArray *)commitDescriptorArgsForItem: (OutlineItem *)outlineItem
                               oldParent: (OutlineItem *)oldParent
                               newParent: (OutlineItem *)newParent
{
    NSString *itemLabel = [outlineItem label];

    NSString *fromLabel = [oldParent label];
    if ([oldParent parent] == nil)
    {
        fromLabel = [[oldParent persistentRoot] name];
    }

    NSString *toLabel = [newParent label];
    if ([newParent parent] == nil)
    {
        toLabel = [[newParent persistentRoot] name];
    }

    return @[itemLabel, fromLabel, toLabel];
}

- (BOOL)pasteFromPasteboard: (NSPasteboard *)pasteboard
                     atItem: (id)newParent
                 childIndex: (NSInteger)index
                  pasteLink: (BOOL)pasteLink
                  pasteCopy: (BOOL)pasteCopy
{
    if (nil == newParent)
    { newParent = [self rootObject]; }

    NSUInteger insertionIndex = index;
    NSLog(@" Drop on to %@ at %d", [newParent label], (int)index);

    NSMutableIndexSet *newSelectedRows = [NSMutableIndexSet indexSet];
    NSMutableArray *outlineItems = [NSMutableArray array];

    for (NSPasteboardItem *pbItem in [pasteboard pasteboardItems])
    {
        id plist = [pbItem propertyListForType: @"org.etoile.outlineItem"];
        if (plist != nil)
        {
            OutlineItem *srcItem = [self outlineItemForPasteboardPropertyList: plist];
            [outlineItems addObject: srcItem];
        }

        plist = [pbItem propertyListForType: @"public.file-url"];
        if (plist != nil)
        {
            NSURL *fileURL = [NSURL URLWithString: plist];
            COAttachmentID *attachmentID = [[[self editingContext] store] importAttachmentFromURL: fileURL];

            OutlineItem *item = [[OutlineItem alloc] initWithObjectGraphContext: [newParent objectGraphContext]];
            item.label = [[fileURL path] lastPathComponent];
            item.attachmentID = attachmentID;
            [outlineItems addObject: item];
        }
    }


    /* Make a link if the user is holding control */

    if (pasteLink &&
        ![[outlineItems objectAtIndex: 0] isKindOfClass: [ItemReference class]]) // Don't make links to link objects
    {
        /*
        OutlineItem *itemToLinkTo = [outlineItems objectAtIndex: 0];
        
        if (insertionIndex == -1) { insertionIndex = [[newParent contents] count]; }
        
        ItemReference *ref = [[ItemReference alloc] initWithParent: newParent
                                                    referencedItem: itemToLinkTo
                                                           context: [[self rootObject] objectContext]];

        [newParent addItem: ref
                   atIndex: insertionIndex];
        
        [self commitWithType: @"kCOTypeMinorEdit"
            shortDescription: @"Drop Link"
             longDescription: [NSString stringWithFormat: @"Drop Link to %@ on %@", [itemToLinkTo label], [newParent label]]];
         */
        NSLog(@"Links unimplemented");
        return;
    }

    // Here we only work on the model.

    for (OutlineItem *outlineItem in outlineItems)
    {
        OutlineItem *oldParent = [outlineItem parent];

        NSArray *commitDescriptorArgs = [self commitDescriptorArgsForItem: outlineItem
                                                                oldParent: oldParent
                                                                newParent: newParent];

        if ([[outlineItem persistentRoot] isEqual: self.persistentRoot]
            && !pasteCopy)
        {
            // Move within persistent root

            NSUInteger oldIndex = [[oldParent contents] indexOfObject: outlineItem];

            NSLog(@"Dropping %@ from %@", [outlineItem label], [oldParent label]);
            if (insertionIndex == -1)
            { insertionIndex = [[newParent contents] count]; }

            if (oldParent == newParent && insertionIndex > oldIndex)
            {
                [oldParent removeItemAtIndex: oldIndex];
                [newParent addItem: outlineItem atIndex: insertionIndex - 1];
            }
            else
            {
                [oldParent removeItemAtIndex: oldIndex];
                [newParent addItem: outlineItem atIndex: insertionIndex++];
            }

            [self commitWithIdentifier: @"drop" descriptionArguments: commitDescriptorArgs];
        }
        else
        {
            // User dragged cross-peristent root, or pasted a copy

            NSString *const commitDescriptor = pasteCopy ? @"drop-copy" : @"drop";

            COCopier *copier = [[COCopier alloc] init];

            ETUUID *destUUID = [copier copyItemWithUUID: [outlineItem UUID]
                                              fromGraph: [outlineItem objectGraphContext]
                                                toGraph: [self objectGraphContext]];

            OutlineItem *copy = (OutlineItem *)[[self objectGraphContext] loadedObjectForUUID: destUUID];

            if (insertionIndex == -1)
            { insertionIndex = [[newParent contents] count]; }

            [newParent addItem: copy atIndex: insertionIndex++];

            if (![[self class] isProjectUndo])
            {
                // Only commit the source and destination persistent roots separately if we're in "document undo" mode
                [self commitWithIdentifier: commitDescriptor
                      descriptionArguments: commitDescriptorArgs];
            }

            // Remove from source

            OutlineItem *oldParent = [outlineItem parent];
            if (!pasteCopy)
            {
                NSUInteger oldIndex = [[oldParent contents] indexOfObject: outlineItem];
                [oldParent removeItemAtIndex: oldIndex];
            }
            Document *document = [oldParent rootObject];
            ETAssert(document != nil);

            OutlineController *sourceController = (OutlineController *)[(ApplicationDelegate *)[NSApp delegate] controllerForDocumentRootObject: document];
            ETAssert(sourceController != nil);

            if (![[self class] isProjectUndo])
            {
                // Only commit the source and destination persistent roots separately if we're in "document undo" mode
                [sourceController commitWithIdentifier: commitDescriptor
                                  descriptionArguments: commitDescriptorArgs];
            }
            else
            {
                // Commit both persistent roots in one commit
                [self.editingContext commitWithIdentifier: [@"org.etoile.ProjectDemo." stringByAppendingString: commitDescriptor]
                                                 metadata: @{
                                                     kCOCommitMetadataShortDescriptionArguments: commitDescriptorArgs}
                                                undoTrack: [self undoTrack]
                                                    error: NULL];
            }
        }
    }

    [outlineView expandItem: newParent];

    for (OutlineItem *outlineItem in outlineItems)
    {
        [newSelectedRows addIndex: [outlineView rowForItem: outlineItem]];
    }
    [outlineView selectRowIndexes: newSelectedRows byExtendingSelection: NO];

    return YES;
}


/* OutlineItem delegate */

- (void)outlineItemDidChange: (OutlineItem *)item
{
    /*OutlineItem *parent = [item parent];
     if (parent != nil)
     {
     [outlineView reloadItem: parent];
     }*/

    /*
     if (item == [self rootDocObject])
     {
     NSLog(@"root didchange");
     [outlineView reloadData];  
     }
     else
     {
     NSLog(@"%@ didchange", [item label]);
     [outlineView reloadItem: item reloadChildren: YES];  
     }*/
}

#pragma mark - EWOutlineViewDelegate

- (void)outlineViewDidStartFieldEditor: (EWOutlineView *)aView
{
    NSLog(@"outlineViewDidStartFieldEditor:");
    if ([self sharingSession] != nil)
    {
        [self sharingSession].paused = YES;
    }
}

- (void)outlineViewDidEndFieldEditor: (EWOutlineView *)aView
{
    NSLog(@"outlineViewDidEndFieldEditor:");

    SharingSession *ss = [self sharingSession];
    if (ss != nil)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            ss.paused = NO;
        });
    }
}

@end
