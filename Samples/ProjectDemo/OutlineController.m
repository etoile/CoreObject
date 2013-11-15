#import "OutlineController.h"
#import "ItemReference.h"
#import "Document.h"
#import "ApplicationDelegate.h"
#import <CoreObject/COSQLiteStore+Debugging.h>

@implementation OutlineController

- (SharingSession *) sharingSession
{
	return _sharingSession;
}

- (void) setSharingSession:(SharingSession *)sharingSession
{
	_sharingSession = sharingSession;
	
	[self updateUIForSharingSession];
}

- (void) updateUIForSharingSession
{
	NSString *docName = [doc documentName];
	NSString *title;
	if ([self isSharing])
	{
		if (_sharingSession.isServer)
		{
			title = [NSString stringWithFormat: @"%@ - sharing with %@", docName, _sharingSession.peerName];
		}
		else
		{
			title = [NSString stringWithFormat: @"%@ - shared by %@", docName, _sharingSession.peerName];
		}
	}
	else
	{
		title = docName;
	}
	[[self window] setTitle: title];

	// Disable the share button if it is a shared document
	if ([self isSharing])
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

- (id)initWithDocument: (id)document
{
	self = [super initWithWindowNibName: @"OutlineWindow"];
	
	if (!self) { return nil; }
	
	doc = document; // weak ref
	
	assert([self rootObject] != nil);
	
//	[[NSNotificationCenter defaultCenter] addObserver: self
//											 selector: @selector(objectGraphContextObjectsDidChange:)
//												 name: COObjectGraphContextObjectsDidChangeNotification
//											   object: [document objectGraphContext]];

	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextObjectsDidChange:)
												 name: COPersistentRootDidChangeNotification
											   object: [document persistentRoot]];

	
	return self;
}

- (BOOL) isSharing
{
	return _sharingSession != nil;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)objectGraphContextObjectsDidChange: (NSNotification*)notif
{
	// HACK: We shouldn't keep the inner object in an ivar, since when the
	// current branch changes, we need to get the new current object graph
	// context. This is a workaround.
	doc = [[doc persistentRoot] rootObject];
	
    //NSLog(@"Reloading outline for %@", doc);
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
	   
	if ([self isSharing])
	{
		name = [name stringByAppendingFormat: @"-%@", [_sharingSession ourName]];
	}
	
    return [COUndoTrack trackForName: name
				  withEditingContext: [[doc persistentRoot] editingContext]];
}

- (void) commitWithIdentifier: (NSString *)identifier
{
	identifier = [@"org.etoile.ProjectDemo." stringByAppendingString: identifier];
	
	[[self persistentRoot] commitWithIdentifier: identifier metadata: nil undoTrack: [self undoStack] error:NULL];
}

- (void)windowDidLoad
{
	[outlineView registerForDraggedTypes:
		@[@"org.etoile.outlineItem", @"public.file-url"]];
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
	
	[self updateUIForSharingSession];
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
	OutlineItem *item = [[OutlineItem alloc]
		initWithObjectGraphContext: [[self rootObject] objectGraphContext]];

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

- (COPersistentRoot *) persistentRoot
{
	return [doc persistentRoot];
}

- (COEditingContext *) editingContext
{
	return [[doc persistentRoot] editingContext];
}

/* IB Actions */

- (IBAction) addItem: (id)sender;
{
	OutlineItem *dest = [self selectedItemParent];
	OutlineItem *item = [self newItem];
	[dest addItem: item];
	
	[outlineView expandItem: dest];
	
	[self commitWithIdentifier: @"add-item"];
	//	TODO: pass [item label] to commit description
}

- (IBAction) addChildItem: (id)sender;
{
	OutlineItem *dest = [self selectedItem];
	
	if ([dest isKindOfClass: [OutlineItem class]])
	{
		OutlineItem *item = [self newItem];
		[dest addItem: item];
		
		[outlineView expandItem: dest];
		
		[self commitWithIdentifier: @"add-child-item"];
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
		
		[self commitWithIdentifier: @"shift-left"];
		
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
		NSLog(@"Requesting object at %d in collection of %d",
			  (int)(indexOfItemInParent - 1), (int)[[parent contents] count]);
		OutlineItem *newParent = [[parent contents] objectAtIndex: (indexOfItemInParent - 1)];
		
		if ([newParent isKindOfClass: [OutlineItem class]])
		{		

			[parent removeItemAtIndex: [[parent contents] indexOfObject: item]];
			[newParent addItem: item];
			
			[self commitWithIdentifier: @"shift-right"]; // TODO: Pass [item label]
			
			[outlineView expandItem: newParent];
			
			[outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex:[outlineView rowForItem: item]]
					 byExtendingSelection: NO];
		}
	}  
}

- (IBAction) shareWith: (id)sender
{
	[(ApplicationDelegate *)[[NSApplication sharedApplication] delegate] shareWithInspectorForDocument: doc];
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

- (void) switchToRevision: (CORevision *)aRevision
{
	[[doc persistentRoot] setCurrentRevision: aRevision];
	
	[self commitWithIdentifier: @"revert"];
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

- (IBAction) branch: (id)sender
{
    COBranch *branch = [[[doc persistentRoot] editingBranch] makeBranchWithLabel: @"Untitled"];
    [[doc persistentRoot] setCurrentBranch: branch];
    [[doc persistentRoot] commit];
}

- (IBAction) stepBackward: (id)sender
{
	NSLog(@"Step back");
	
	if ([[[doc persistentRoot] editingBranch] canUndo])
		[[[doc persistentRoot] editingBranch] undo];
	
	[self commitWithIdentifier: @"step-backward"];
}

- (IBAction) stepForward: (id)sender
{
	NSLog(@"Step forward");
	
	if ([[[doc persistentRoot] editingBranch] canRedo])
		[[[doc persistentRoot] editingBranch] redo];
	
	[self commitWithIdentifier: @"step-forward"];
}

- (IBAction) showGraphvizHistoryGraph: (id)sender
{
	[[[doc persistentRoot] store] showGraphForPersistentRootUUID: [[doc persistentRoot] UUID]];
}

- (IBAction) history: (id)sender
{
	//[(ApplicationDelegate *)[[NSApp delegate] historyController] showHistoryForDocument: doc];
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
	OutlineItem *itemToDelete = [self selectedItem];
	if (itemToDelete != nil && itemToDelete != [self rootObject])
	{
		NSInteger index = [[[itemToDelete parent] contents] indexOfObject: itemToDelete];
		assert(index != NSNotFound);
		NSString *label = [itemToDelete label];
		[[itemToDelete parent] removeItemAtIndex: index];
		
		[self commitWithIdentifier: @"delete"];
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
			OutlineController *otherController = [(ApplicationDelegate *)[[NSApplication sharedApplication] delegate]
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

- (BOOL) outlineView: (NSOutlineView *)ov isItemExpandable: (id)item
{
	return [self outlineView: ov numberOfChildrenOfItem: item] > 0;
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
		NSString *oldLabel = [item label];
		[item setLabel: object];
	
		[self commitWithIdentifier: @"rename"]; // TODO: Use [item label] in description
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pb
{
	NSMutableArray *pbItems = [NSMutableArray array];
    
	for (OutlineItem *outlineItem in items)
	{
        NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
        
        // FIXME: Pass editing branch?
		[item setPropertyList: @{ @"persistentRoot" : [[[outlineItem persistentRoot] UUID] stringValue],
                                  @"uuid" : [[outlineItem UUID] stringValue] }
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

- (IBAction)copy:(id)sender
{
	NSArray *rows = [self selectedRows];
	
	if ([rows count] == 0)
	{
		NSLog(@"Nothing to copy");
		return;
	}

	[self outlineView: outlineView writeItems: rows toPasteboard: [NSPasteboard generalPasteboard]];
}

- (IBAction)paste:(id)sender
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

- (IBAction)cut:(id)sender
{
	[self copy: sender];
	[self delete: sender];
}

#pragma mark drag & drop

- (OutlineItem *) outlineItemForPasteboardPropertyList: (id)plist
{
    ETUUID *persistentRootUUID = [ETUUID UUIDWithString: plist[@"persistentRoot"]];
    ETUUID *objectUUID = [ETUUID UUIDWithString: plist[@"uuid"]];
    
    COPersistentRoot *persistentRoot = [[[doc persistentRoot] parentContext] persistentRootForUUID: persistentRootUUID];
    return (OutlineItem *)[persistentRoot loadedObjectForUUID: objectUUID];
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

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)newParent childIndex:(NSInteger)index
{
	NSLog(@"Dragging mask: %d", (int)[info draggingSourceOperationMask]);
	
	return [self pasteFromPasteboard: [info draggingPasteboard]
							  atItem: newParent
						  childIndex: index
						   pasteLink: [info draggingSourceOperationMask] == NSDragOperationLink
						   pasteCopy: [info draggingSourceOperationMask] == NSDragOperationCopy];
}

- (BOOL) pasteFromPasteboard: (NSPasteboard *)pasteboard atItem:(id)newParent childIndex:(NSInteger)index pasteLink: (BOOL)pasteLink pasteCopy: (BOOL)pasteCopy
{
	if (nil == newParent) { newParent = [self rootObject]; }
	
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
			NSData *attachmentID = [[[self editingContext] store] importAttachmentFromURL: fileURL];
			
			OutlineItem *item = [[OutlineItem alloc] initWithObjectGraphContext: [newParent objectGraphContext]];
			item.label = [NSString stringWithFormat: @"%@ imported as %@", fileURL, attachmentID];
			
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
        if ([[outlineItem persistentRoot] isEqual: [doc persistentRoot]]
			&& !pasteCopy)
        {
			// Move within persistent root
			
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
            
            [self commitWithIdentifier: @"drop"];
        }
        else
        {
            // User dragged cross-peristent root
            
            COCopier *copier = [[COCopier alloc] init];
			
            ETUUID *destUUID = [copier copyItemWithUUID: [outlineItem UUID]
                                              fromGraph: [outlineItem objectGraphContext]
                                                toGraph: [doc objectGraphContext]];
            
            OutlineItem *copy = (OutlineItem *)[[doc objectGraphContext] loadedObjectForUUID: destUUID];
			
            if (insertionIndex == -1) { insertionIndex = [[newParent contents] count]; }
            
            [newParent addItem: copy atIndex: insertionIndex++];
            
			
			if (![[self class] isProjectUndo])
			{
				// Only commit the source and destination persistent roots separately if we're in "document undo" mode
				[self commitWithIdentifier: @"drop"];
			}
            
            // Remove from source
			
            OutlineItem *oldParent = [outlineItem parent];
			if (!pasteCopy)
			{
				NSUInteger oldIndex = [[oldParent contents] indexOfObject: outlineItem];
				[oldParent removeItemAtIndex: oldIndex];
			}
			
            OutlineController *sourceController = [(ApplicationDelegate *)[NSApp delegate] controllerForDocumentRootObject: [oldParent document]];
			
			if (![[self class] isProjectUndo])
			{
				// Only commit the source and destination persistent roots separately if we're in "document undo" mode
				[sourceController commitWithIdentifier: @"drop"];
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
