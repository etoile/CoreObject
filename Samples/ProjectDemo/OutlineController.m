#import "OutlineController.h"
#import "SharingController.h"
#import "ItemReference.h"
#import "Document.h"
#import "ApplicationDelegate.h"

@implementation OutlineController

- (id)initWithDocument: (id)document isSharing: (BOOL)sharing;
{
	self = [super initWithWindowNibName: @"OutlineWindow"];
	
	if (!self) { [self release]; return nil; }
	
	doc = document; // weak ref
	isSharing = sharing;
	
	assert([self rootObject] != nil);
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextObjectsDidChange:)
												 name: COObjectGraphContextObjectsDidChangeNotification
											   object: [document objectGraphContext]];
	
	return self;
}

- (id)initWithDocument: (id)document
{
	return [self initWithDocument:document isSharing: NO];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (void)objectGraphContextObjectsDidChange: (NSNotification*)notif
{
    COObjectGraphContext *objGraph = [notif object];
    assert(objGraph != nil);
    assert([objGraph isKindOfClass: [COObjectGraphContext class]]);
    
    NSLog(@"Reloading outline for %@", doc);
    [outlineView reloadData];
}

- (Document *)projectDocument
{
	return doc;
}
- (OutlineItem *)rootObject
{
	return (OutlineItem *)[[self projectDocument] rootDocObject];
}

+ (BOOL) isProjectUndo
{
	NSString *mode = [[NSUserDefaults standardUserDefaults] valueForKey: @"UndoMode"];
	
	return (mode == nil || [mode isEqualToString: @"Project"]);
}

- (COUndoTrack *) undoStack
{
    NSString *name = nil;
	
	if ([[self class] isProjectUndo])
	{
		name = @"org.etoile.projectdemo";
	}
	else
	{
		name = [NSString stringWithFormat: @"org.etoile.projectdemo-%@",
			[[doc persistentRoot] UUID]];
	}
	   
    return [COUndoTrack trackForName: name
				  withEditingContext: [[doc persistentRoot] editingContext]];
}

- (void) commitWithType: (NSString*)type
       shortDescription: (NSString*)shortDescription
        longDescription: (NSString*)longDescription;
{
	[[doc persistentRoot] commitWithIdentifier: @"foo" metadata: nil undoTrack: [self undoStack] error:NULL];
}

- (void)windowDidLoad
{
	[outlineView registerForDraggedTypes:
		[NSArray arrayWithObject:@"org.etoile.outlineItem"]];
	[outlineView setDelegate: self];
	[outlineView setTarget: self];
	[outlineView setDoubleAction: @selector(doubleClick:)];
	
	//NSLog(@"Got rect %@ for doc %@", NSStringFromRect([doc screenRectValue]), [doc uuid]);
	
	if (!NSIsEmptyRect([doc screenRect]))
	{
		// Disable automatic positioning
		[self setShouldCascadeWindows: NO];
		[[self window] setFrame: [doc screenRect] display: NO];
	}

	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(windowFrameDidChange:)
												 name: NSWindowDidMoveNotification 
											   object: [self window]];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(windowFrameDidChange:)
												 name: NSWindowDidEndLiveResizeNotification 
											   object: [self window]];	
	
	if ([doc documentName])
	{
		NSString *title;
		if (isSharing)
		{
			title = [NSString stringWithFormat: @"Shared Document %@ From %@",
					 [doc documentName],
					 [[NSClassFromString(@"SharingController") sharedSharingController] fullNameOfUserSharingDocument: doc]];
		}
		else
		{
			title = [doc documentName];
		}
		[[self window] setTitle: title]; 
	}
	
	// Disable the share button if it is a shared document
	if (isSharing)
	{
		for (NSToolbarItem *item in [[[self window] toolbar] items])
		{
			if ([[item itemIdentifier] isEqual: @"share"])
			{
				[item setEnabled: NO];
			}
		}
	}
}

- (void)windowFrameDidChange:(NSNotification*)notification
{
	// This was rather annoying so I disabled it
//	[doc setScreenRect: [[self window] frame]];
//	
////	assert([[doc objectGraphContext] objectHasChanges: [doc UUID]]);
//	
//	[self commitWithType: @"kCOTypeMinorEdit"
//		shortDescription: @"Move Window"
//		 longDescription: [NSString stringWithFormat: @"Move to %@", NSStringFromRect([doc screenRect])]];	
}

- (void)windowWillClose:(NSNotification *)notification
{
	NSLog(@"TODO: handle outline closing");
}

static int i = 0;

- (OutlineItem *) newItem
{
	OutlineItem *item = [[OutlineItem alloc] initWithEntityDescription: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.OutlineItem"]
												 objectGraphContext: [[self rootObject] objectGraphContext]];

	[item setLabel: [NSString stringWithFormat: @"Item %d", i++]];
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
	
	[self commitWithType: @"kCOTypeMinorEdit"
		shortDescription: @"Add Item"
		 longDescription: [NSString stringWithFormat: @"Add item %@", [item label]]];
}

- (IBAction) addChildItem: (id)sender;
{
	OutlineItem *dest = [self selectedItem];
	
	if ([dest isKindOfClass: [OutlineItem class]])
	{
		OutlineItem *item = [self newItem];
		[dest addItem: item];
		
		[outlineView expandItem: dest];
		
		[self commitWithType: @"kCOTypeMinorEdit"
			shortDescription: @"Add Child Item"
			 longDescription: [NSString stringWithFormat: @"Add child item %@ to %@", [item label], [dest label]]];
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
		[item retain];
		[parent removeItemAtIndex: indexOfItemInParent];
		[grandparent addItem: item atIndex: [[grandparent contents] indexOfObject: parent] + 1];
		[item release];
		
		[self commitWithType: @"kCOTypeMinorEdit"
			shortDescription: @"Shift Left"
			 longDescription: [NSString stringWithFormat: @"Shift left item %@", [item label]]];
		
		[outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[outlineView rowForItem: item]]
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
		NSLog(@"Requesting object at %d in collection of %d", indexOfItemInParent - 1, [[parent contents] count]);
		OutlineItem *newParent = [[parent contents] objectAtIndex: (indexOfItemInParent - 1)];
		
		if ([newParent isKindOfClass: [OutlineItem class]])
		{		
			[item retain];
			[parent removeItemAtIndex: [[parent contents] indexOfObject: item]];
			[newParent addItem: item];
			[item release];
			
			[self commitWithType: @"kCOTypeMinorEdit"
				shortDescription: @"Shift Right"
				 longDescription: [NSString stringWithFormat: @"Shift right item %@", [item label]]];
			
			[outlineView expandItem: newParent];
			
			[outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[outlineView rowForItem: item]]
					 byExtendingSelection: NO];
		}
	}  
}

- (IBAction) shareWith: (id)sender
{
	[[[NSApplication sharedApplication] delegate] shareWithInspectorForDocument: doc];
}

- (IBAction)moveToTrash:(id)sender
{
	NSLog(@"Trash %@", self);
	
	[doc persistentRoot].deleted = YES;
	
	NSMutableSet *docs = [[doc project] mutableSetValueForKey: @"documents"];
	assert([docs containsObject: doc]);
	[docs removeObject: doc];
	
	[[[doc persistentRoot] editingContext] commit];
	
	// FIXME: Hack
	[self close];
}

/* History stuff */

- (IBAction) projectDemoUndo: (id)sender
{
    COUndoTrack *stack = [self undoStack];
    
    if ([stack canUndo])
    {
        [stack undo];
    }
}
- (IBAction) projectDemoRedo: (id)sender
{
    COUndoTrack *stack = [self undoStack];

    if ([stack canRedo])
    {
        [stack redo];
    }
}

- (IBAction) stepBackward: (id)sender
{
	NSLog(@"Step back");
	
	if ([[[doc persistentRoot] editingBranch] canUndo])
		[[[doc persistentRoot] editingBranch] undo];
	
	[self commitWithType: @"kCOTypeMinorEdit"
		shortDescription: @"Step Back"
		 longDescription: [NSString stringWithFormat: @"Step Back"]];
}
- (IBAction) stepForward: (id)sender
{
	NSLog(@"Step forward");
	
	if ([[[doc persistentRoot] editingBranch] canRedo])
		[[[doc persistentRoot] editingBranch] redo];
	
	[self commitWithType: @"kCOTypeMinorEdit"
		shortDescription: @"Step Forward"
		 longDescription: [NSString stringWithFormat: @"Step Forward"]];
}

- (IBAction) history: (id)sender
{
	[[[NSApp delegate] historyController] showHistoryForDocument: doc];
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

- (void)deleteForward:(id)sender
{
	id itemToDelete = [self selectedItem];
	if (itemToDelete != nil && itemToDelete != [self rootObject])
	{
		NSInteger index = [[[itemToDelete parent] contents] indexOfObject: itemToDelete];
		assert(index != NSNotFound);
		NSString *label = [[itemToDelete label] retain];
		[[itemToDelete parent] removeItemAtIndex: index];
		
		[self commitWithType: @"kCOTypeMinorEdit"
			shortDescription: @"Delete Item"
			 longDescription: [NSString stringWithFormat: @"Delete Item %@", label]];

		[label release];
	}
}

- (void)delete:(id)sender
{
	[self deleteForward: sender];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[self interpretKeyEvents: [NSArray arrayWithObject:theEvent]];
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
			OutlineController *otherController = [[[NSApplication sharedApplication] delegate]
												  controllerForDocumentRootObject: root];
			assert(otherController != nil);
			
			// FIXME: ugly
			
			[[otherController window] makeKeyAndOrderFront: nil];
			[otherController->outlineView expandItem: nil expandChildren: YES];
			[otherController->outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[otherController->outlineView rowForItem: target]]
					 byExtendingSelection: NO];
		}
		else if ([item isKindOfClass: [OutlineItem class]])
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

/* NSOutlineView delegate */

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([item isKindOfClass: [OutlineItem class]])
	{
		return YES;
	}
	return NO;
}

/* NSOutlineView data source */

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	return [[item contents] objectAtIndex: index];
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item
{
	return [self outlineView: outlineView numberOfChildrenOfItem: item] > 0;
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	if ([item isKindOfClass: [OutlineItem class]])
	{
		return [[item contents] count];
	}
	else
	{
		return 0;
	}
}

- (id) outlineView: (NSOutlineView *)outlineView objectValueForTableColumn: (NSTableColumn *)column byItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	return [item label];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (nil == item) { item = [self rootObject]; }

	if ([item isKindOfClass: [OutlineItem class]])
	{
		NSString *oldLabel = [[item label] retain];
		[item setLabel: object];
	
		[self commitWithType: @"kCOTypeMinorEdit"
			shortDescription: @"Edit Label"
			 longDescription: [NSString stringWithFormat: @"Edit label from %@ to %@", oldLabel, [item label]]];
	
		[oldLabel release];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pb
{
	NSMutableArray *pbItems = [NSMutableArray array];
    
	for (OutlineItem *outlineItem in items)
	{
        NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
        
        // FIXME: Pass editing branch?
		[item setPropertyList: @{ @"persistentRoot" : [[[outlineItem persistentRoot] UUID] stringValue],
                                  @"uuid" : [[outlineItem UUID] stringValue] }
					  forType: @"org.etoile.outlineItem"];
		[pbItems addObject: item];
	}
	
	[pb clearContents];
	return [pb writeObjects: pbItems];
}

- (OutlineItem *) outlineItemForPasteboardPropertyList: (id)plist
{
    ETUUID *persistentRootUUID = [ETUUID UUIDWithString: plist[@"persistentRoot"]];
    ETUUID *objectUUID = [ETUUID UUIDWithString: plist[@"uuid"]];
    
    COPersistentRoot *persistentRoot = [[[doc persistentRoot] parentContext] persistentRootForUUID: persistentRootUUID];
    return (OutlineItem *)[persistentRoot objectWithUUID: objectUUID];
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	if (item != nil && ![item isKindOfClass: [OutlineItem class]])
	{
		return NSDragOperationNone;
	}
    
    // Ensure the destination isn't a child of, or equal to, the source
    
	for (NSPasteboardItem *pbItem in [[info draggingPasteboard] pasteboardItems])
	{
        id plist = [pbItem propertyListForType: @"org.etoile.outlineItem"];	
        OutlineItem *srcItem = [self outlineItemForPasteboardPropertyList: plist];
        
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
        id plist = [pbItem propertyListForType: @"org.etoile.outlineItem"];	
        OutlineItem *srcItem = [self outlineItemForPasteboardPropertyList: plist];
		[outlineItems addObject: srcItem];
	}
	
	
	/* Make a link if the user is holding control */
	
	if ([info draggingSourceOperationMask] == NSDragOperationLink &&
		![[outlineItems objectAtIndex: 0] isKindOfClass: [ItemReference class]]) // Don't make links to link objects
	{
		OutlineItem *itemToLinkTo = [outlineItems objectAtIndex: 0];
		
		if (insertionIndex == -1) { insertionIndex = [[newParent contents] count]; }
		
		ItemReference *ref = [[ItemReference alloc] initWithParent: newParent
													referencedItem: itemToLinkTo
														   context: [[self rootObject] objectContext]];
		[ref autorelease];
		
		[newParent addItem: ref 
				   atIndex: insertionIndex]; 
		
		[self commitWithType: @"kCOTypeMinorEdit"
			shortDescription: @"Drop Link"
			 longDescription: [NSString stringWithFormat: @"Drop Link to %@ on %@", [itemToLinkTo label], [newParent label]]];
		
		return;
	}
	
	// Here we only work on the model.
	
	for (OutlineItem *outlineItem in outlineItems)
	{
        if ([[outlineItem persistentRoot] isEqual: [doc persistentRoot]])
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
            
            [self commitWithType: @"kCOTypeMinorEdit"
                shortDescription: @"Drop Items"
                 longDescription: [NSString stringWithFormat: @"Drop %d items on %@", (int)[outlineItems count], [newParent label]]];
        }
        else
        {
            // User dragged cross-peristent root
            
            COCopier *copier = [[[COCopier alloc] init] autorelease];

            ETUUID *destUUID = [copier copyItemWithUUID: [outlineItem UUID]
                                              fromGraph: [outlineItem objectGraphContext]
                                                toGraph: [doc objectGraphContext]];
            
            OutlineItem *copy = (OutlineItem *)[[doc objectGraphContext] objectWithUUID: destUUID];

            if (insertionIndex == -1) { insertionIndex = [[newParent contents] count]; }
            
            [newParent addItem: copy atIndex: insertionIndex++];
            
			
			if (![[self class] isProjectUndo])
			{
				// Only commit the source and destination persistent roots separately if we're in "document undo" mode
				[self commitWithType: @"kCOTypeMinorEdit"
					shortDescription: @"Drop Items"
					 longDescription: [NSString stringWithFormat: @"Drop %d items on %@", (int)[outlineItems count], [newParent label]]];
			}
            
            // Remove from source

            OutlineItem *oldParent = [outlineItem parent];
            NSUInteger oldIndex = [[oldParent contents] indexOfObject: outlineItem];
            [oldParent removeItemAtIndex: oldIndex];
            
            OutlineController *sourceController = [(ApplicationDelegate *)[NSApp delegate] controllerForDocumentRootObject: [oldParent document]];
			
			if (![[self class] isProjectUndo])
			{
				// Only commit the source and destination persistent roots separately if we're in "document undo" mode
				[sourceController commitWithType: @"kCOTypeMinorEdit"
								shortDescription: @"Drag Items"
								 longDescription: [NSString stringWithFormat: @"Drop %d items on %@", (int)[outlineItems count], [newParent label]]];
			}
			else
			{
				// Commit both persistent roots in one commit
				[[[doc persistentRoot] editingContext] commitWithUndoTrack: [self undoStack]];
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

- (void)outlineItemDidChange: (OutlineItem*)item
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

@end
