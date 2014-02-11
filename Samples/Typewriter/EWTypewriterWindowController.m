/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>
#import "EWTypewriterWindowController.h"
#import "EWDocument.h"
#import "EWAppDelegate.h"
#import "TypewriterDocument.h"

@interface EWTagListDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
	NSMutableSet *oldSelection;
}
@property (nonatomic, unsafe_unretained) EWTypewriterWindowController *owner;
@property (nonatomic, strong) NSOutlineView *outlineView;
- (void)reloadData;
@end

@interface EWNoteListDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
	NSMutableSet *oldSelection;
}
@property (nonatomic, unsafe_unretained) EWTypewriterWindowController *owner;
@property (nonatomic, strong) NSTableView *tableView;
- (void)reloadData;
@end

@implementation EWTypewriterWindowController

/**
 * Pasteboard item property list is an NSString persistent root UUID
 */
static NSString * EWNoteDragType = @"org.etoile.Typewriter.Note";
static NSString * EWTagDragType = @"org.etoile.Typewriter.Tag";

#pragma mark - properties

@synthesize notesTable = notesTable;
@synthesize undoTrack = undoTrack;

- (COEditingContext *) editingContext
{
	return [(EWDocument *)[self document] editingContext];
}

- (NSArray *) arrangedNotePersistentRoots
{
	NSMutableArray *results = [NSMutableArray new];
	
	NSSet *set = [self.editingContext.persistentRoots filteredSetUsingPredicate:
				  [NSPredicate predicateWithBlock: ^(id object, NSDictionary *bindings) {
					COPersistentRoot *persistentRoot = object;
					return [[persistentRoot rootObject] isKindOfClass: [TypewriterDocument class]];
				  }]];
	
	[results setArray: [set allObjects]];
	[results sortUsingDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: @"modificationDate" ascending: NO]]];
	
	// Filter by tag
	
	COTag *selectedTag = [self selectedTag];
	
	[results filterUsingPredicate:
	 [NSPredicate predicateWithBlock: ^(id object, NSDictionary *bindings) {
		if (selectedTag == nil)
		{
			return YES;
		}
		else
		{
			NSArray *tagContents = [selectedTag content];
			id rootObject = [object rootObject];
			return [tagContents containsObject: rootObject];
		}
	}]];
	
	return results;
}

- (NSArray *) selectedNotePersistentRoots
{
	return [[self arrangedNotePersistentRoots] objectsAtIndexes: [notesTable selectedRowIndexes]];
}

- (COTag *) selectedTag
{
	NSInteger selectedRow = [tagsOutline selectedRow];
	if (selectedRow != -1)
	{
		id object = [tagsOutline itemAtRow: selectedRow];
		if ([object isTag])
		{
			return object;
		}
	}
	return nil;
}

- (COTagGroup *) selectedTagGroup
{
	NSInteger selectedRow = [tagsOutline selectedRow];
	if (selectedRow != -1)
	{
		id object = [tagsOutline itemAtRow: selectedRow];
		if ([object isKindOfClass: [COTagGroup class]])
		{
			return object;
		}
	}
	return nil;
}

- (void) dealloc
{
	[textStorage setDelegate: nil];
	[tagsOutline setDelegate: nil];
	[notesTable setDelegate: nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - NSWindowController overrides

- (void)windowDidLoad
{
	// Disable AppKit's automatic restoration; we implement our own in
	// -[EWAppDelegate applicationDidFinishLaunching:]
	[[self window] setRestorable: NO];
	
	undoManagerBridge = [[EWUndoManager alloc] init];
	[undoManagerBridge setDelegate: self];
	
	undoTrack = [COUndoTrack trackForName: @"typewriter" withEditingContext: self.editingContext];
	
	ETAssert(tagsOutline != nil);
	tagListDataSource = [EWTagListDataSource new];
	tagListDataSource.owner = self;
	tagListDataSource.outlineView = tagsOutline;
	[tagsOutline setDataSource: tagListDataSource];
	[tagsOutline setDelegate: tagListDataSource];
	
	ETAssert(notesTable != nil);
	noteListDataSource = [EWNoteListDataSource new];
	noteListDataSource.owner = self;
	noteListDataSource.tableView = notesTable;
	[notesTable setDataSource: noteListDataSource];
	[notesTable setDelegate: noteListDataSource];

	// Drag & drop
	
	[tagsOutline registerForDraggedTypes: @[EWNoteDragType, EWTagDragType]];
	
	// Text view setup
	
	[textView setDelegate: self];
	
	// Set initial text view contents
	
	if ([[self selectedNotePersistentRoots] count] > 0)
	{
		[self selectNote: [self selectedNotePersistentRoots][0]];
	}
	else
	{
		[self selectNote: nil];
	}
	
	
	// Observe editing context changes
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(editingContextChanged:)
												 name: COEditingContextDidChangeNotification
											   object: self.editingContext];
}

#pragma mark - Notification methods

- (void) editingContextChanged: (NSNotification *)notif
{
	[tagListDataSource reloadData];
	[noteListDataSource reloadData];
}

#pragma mark - IBActions

- (IBAction) addTag:(id)sender
{
	COTagGroup *targetTagGroup = [self selectedTagGroup];
	if (targetTagGroup == nil)
		targetTagGroup = [self defaultTagGroup];
		
	COTag *newTag = [[COTag alloc] initWithObjectGraphContext: [[self tagLibrary] objectGraphContext]];
	newTag.name = @"New Tag";
	[targetTagGroup addObject: newTag];
	
	[self commitWithIdentifier: @"add-tag" descriptionArguments: @[]];
	[tagListDataSource reloadData];
}

- (IBAction) addTagGroup:(id)sender
{
	COTagGroup *newTagGroup = [[COTagGroup alloc] initWithObjectGraphContext: [[self tagLibrary] objectGraphContext]];
	newTagGroup.name = @"New Tag Group";
	[[[self tagLibrary] mutableArrayValueForKey: @"tagGroups"] addObject: newTagGroup];
	
	[self commitWithIdentifier: @"add-tag-group" descriptionArguments: @[]];
	[tagListDataSource reloadData];
}

- (IBAction) addNote:(id)sender
{
	COPersistentRoot *newNote = [self.editingContext insertNewPersistentRootWithEntityName: @"TypewriterDocument"];
	NSMutableDictionary *md = [NSMutableDictionary dictionaryWithDictionary: newNote.metadata];
	[md addEntriesFromDictionary: @{ @"label" : @"Untitled Note" }];
	newNote.metadata = md;
	
	COTag *currentTag = [self selectedTag];
	if (currentTag != nil)
	{
		[currentTag addObject: [newNote rootObject]];
	}
	
	[self commitWithIdentifier: @"add-note" descriptionArguments: @[]];
	[noteListDataSource reloadData];
}

- (IBAction) duplicate:(id)sender
{
	if ([[self window] firstResponder] == notesTable)
	{
		NSArray *selections = [self selectedNotePersistentRoots];
		if ([selections count] == 0)
			return;
		
		COPersistentRoot *selectedPersistentRoot = selections[0];
		COPersistentRoot *copyOfSelection = [selectedPersistentRoot.currentBranch makePersistentRootCopy];

		NSString *sourceLabel = selectedPersistentRoot.metadata[@"label"];
		
		NSMutableDictionary *md = [NSMutableDictionary dictionaryWithDictionary: copyOfSelection.metadata];
		[md addEntriesFromDictionary: @{ @"label" : [NSString stringWithFormat: @"Copy of %@", sourceLabel] }];
		copyOfSelection.metadata = md;
		
		[self commitWithIdentifier: @"duplicate-note" descriptionArguments: @[sourceLabel]];
		[noteListDataSource reloadData];
	}
}

#pragma mark - EWUndoManagerDelegate

- (void) undo
{
	[undoTrack undo];
}
- (void) redo
{
	[undoTrack redo];
}

- (BOOL) canUndo
{
	return [undoTrack canUndo];
}

- (BOOL) canRedo
{
	return [undoTrack canRedo];
}

- (NSString *) undoMenuItemTitle
{
	return [undoTrack undoMenuItemTitle];
}
- (NSString *) redoMenuItemTitle
{
	return [undoTrack redoMenuItemTitle];
}

#pragma mark - NSWindowDelegate

-(NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
	NSLog(@"asked for undo manager");
	return (NSUndoManager *)undoManagerBridge;
}

#pragma mark - NSTextViewDelegate

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	changedByUser = YES;
	return YES;
}

#pragma mark - NSTextStorageDelegate

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSString *editedText = [[textStorage string] substringWithRange: [textStorage editedRange]];
	
	NSLog(@"Text storage did process editing. %@ edited range: %@ = %@", notification.userInfo, NSStringFromRange([textStorage editedRange]), editedText);
	[textView setNeedsDisplay: YES];
	
	if (changedByUser)
	{
		changedByUser = NO;
	}
	else if ([selectedNote.objectGraphContext hasChanges])
	{
		NSLog(@"Processing editing with changes, but it wasn't the user's changes, ignoring");
		return;
	}
	
	if ([selectedNote.objectGraphContext hasChanges])
	{
		[self commitWithIdentifier: @"modify-text" descriptionArguments: @[]];
	}
	else
	{
		NSLog(@"No changes, not committing");
	}
}

#pragma mark - NSResponder

/**
 * The "delete" menu item is connected to this action
 */
- (void)delete: (id)sender
{
	if ([[self window] firstResponder] == notesTable)
	{
		NSMutableString *label = [NSMutableString new];
		for (COPersistentRoot *selectedPersistentRoot in [self selectedNotePersistentRoots])
		{
			selectedPersistentRoot.deleted = YES;
			if (selectedPersistentRoot.metadata[@"label"] != nil)
			{
				[label appendFormat: @" %@", selectedPersistentRoot.metadata[@"label"]];
			}
		}
		
		[self commitWithIdentifier: @"delete-note" descriptionArguments: @[label]];
		[noteListDataSource reloadData];
	}
	else if ([[self window] firstResponder] == tagsOutline)
	{
		if ([self selectedTag] != nil)
		{
			COTag *tag = [self selectedTag];
			NSSet *tagGroups = [tag tagGroups];
			for (COTagGroup *parentGroup in tagGroups)
			{
				[parentGroup removeObject: tag];
			}
			[self commitWithIdentifier: @"delete-tag" descriptionArguments: @[tag.name != nil ? tag.name : @""]];
			[tagListDataSource reloadData];
		}
		if ([self selectedTagGroup] != nil)
		{
			COTagGroup *tagGroup = [self selectedTagGroup];
			[[[self tagLibrary] mutableArrayValueForKey: @"tagGroups"] removeObject: tagGroup];
			[self commitWithIdentifier: @"delete-tag-group" descriptionArguments: @[tagGroup.name != nil ? tagGroup.name : @""]];
			[tagListDataSource reloadData];
		}
	}
}

#pragma mark - Private

- (void) selectNote: (COPersistentRoot *)aNote
{
	selectedNote = aNote;
	
	if (selectedNote == nil)
	{
		// Nothing selected
		NSLog(@"Nothing selected");
		[textView setEditable: NO];
		[textView setHidden: YES];
		return;
	}
	else
	{
		[textView setEditable: YES];
		[textView setHidden: NO];
	}
	
	TypewriterDocument *doc = [selectedNote rootObject];

	if ([doc attrString] != [textStorage backing])
	{
		NSLog(@"Select %@. Old text storage: %p", selectedNote, textStorage);

		textStorage = [[COAttributedStringWrapper alloc] initWithBacking: [doc attrString]];
		[textStorage setDelegate: self];
		
		[textView.layoutManager replaceTextStorage: textStorage];

		NSLog(@"TV's ts: %p, New Text storage; %p", [textView textStorage], textStorage);
	}
	else
	{
		NSLog(@"selectNote: the attributed string hasn't changed");
	}
	
	// Set window title
	if (selectedNote.metadata[@"label"] != nil)
	{
		[[self window] setTitle: selectedNote.metadata[@"label"]];
	}
	else
	{
		[[self window] setTitle: @"Typewriter"];
	}
}

/**
 * call with nil to indicate no selection
 */
- (void) selectTag: (COTag *)aTag
{
	NSLog(@"Selected tag %@", aTag);
	
	[noteListDataSource reloadData];
}

- (void) commitWithIdentifier: (NSString *)identifier descriptionArguments: (NSArray*)args
{
	identifier = [@"org.etoile.Typewriter." stringByAppendingString: identifier];
	
	NSMutableDictionary *metadata = [NSMutableDictionary new];
	if (args != nil)
		metadata[kCOCommitMetadataShortDescriptionArguments] = args;
	
	[self.editingContext commitWithIdentifier: identifier metadata: metadata undoTrack: undoTrack error: NULL];
}

- (COTagLibrary *)tagLibrary
{
	return [[[self document] libraryPersistentRoot] rootObject];
}

- (COTagGroup *)defaultTagGroup
{
	return [self tagLibrary].tagGroups[0];
}

@end

@implementation EWTagListDataSource

@synthesize owner, outlineView;

- (id) init
{
	SUPERINIT;
	oldSelection = [NSMutableSet new];
	return self;
}

- (id) rootObject
{
	return [owner tagLibrary];
}

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	
	if ([item isLibrary])
	{
		return [[(COTagLibrary *)item tagGroups] objectAtIndex: index];
	}
	
	return [[(COCollection *)item content] objectAtIndex: index];
}

- (BOOL) outlineView: (NSOutlineView *)ov isItemExpandable: (id)item
{
	return [self outlineView: ov numberOfChildrenOfItem: item] > 0;
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	
	if ([item isLibrary])
	{
		return [[(COTagLibrary *)item tagGroups] count];
	}
	else if ([item isKindOfClass: [COTagGroup class]])
	{
		return [[(COCollection *)item content] count];
	}
	
	return 0;
}

- (id) outlineView: (NSOutlineView *)outlineView objectValueForTableColumn: (NSTableColumn *)column byItem: (id)item
{
	if (nil == item) { item = [self rootObject]; }
	return [(COObject *)item name];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (nil == item) { item = [self rootObject]; }
	
	NSString *oldName = [item name] != nil ? [item name] : @"";
	NSString *newName = [object stringValue] != nil ? [object stringValue] : @"";
	
	[(COObject *)item setName: object];
	[self.owner commitWithIdentifier: @"rename-tag" descriptionArguments: @[oldName, newName]];
}

- (void)cacheSelection
{
	[oldSelection removeAllObjects];
	NSIndexSet *indexes = [self.outlineView selectedRowIndexes];
	for (NSUInteger i = [indexes firstIndex]; i != NSNotFound; i = [indexes indexGreaterThanIndex: i])
	{
		[oldSelection addObject: [self.outlineView itemAtRow: i]];
	}
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[self cacheSelection];
	[self.owner selectTag: nil];
}

- (void)reloadData
{
	[self.outlineView reloadData];
	
	NSMutableIndexSet *newSelectedRows = [NSMutableIndexSet new];
	for (id obj in oldSelection)
	{
		NSInteger row = [self.outlineView rowForItem: obj];
		if (row != -1)
		{
			[newSelectedRows addIndex: row];
		}
	}
	[self.outlineView selectRowIndexes: newSelectedRows byExtendingSelection: NO];
	[self cacheSelection];
}

#pragma mark Drag & Drop

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	if ([[[info draggingPasteboard] types] containsObject: EWTagDragType])
	{
		if ([item isKindOfClass: [COTagGroup class]])
			return NSDragOperationMove;
	}
	else if ([[[info draggingPasteboard] types] containsObject: EWNoteDragType])
	{
		if ([item isTag])
			return NSDragOperationMove;
	}
	return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
	NSPasteboard *pasteboard = [info draggingPasteboard];
	
	if ([[[info draggingPasteboard] types] containsObject: EWTagDragType])
	{
		COTagGroup *tagGroup = item;
		ETAssert([tagGroup isKindOfClass: [COTagGroup class]]);
		
		id plist = [pasteboard propertyListForType: EWTagDragType];
		COTag *tag = [[[self.owner tagLibrary] objectGraphContext] loadedObjectForUUID: [ETUUID UUIDWithString: plist]];
		ETAssert(tag != nil);
			
		[tagGroup addObject: tag];
		
		[self.owner commitWithIdentifier: @"move-tag" descriptionArguments: @[tag.name != nil ? tag.name : @""]];
	}
	else if ([[[info draggingPasteboard] types] containsObject: EWNoteDragType])
	{
		COTag *tag = item;
		ETAssert([tag isTag]);
		
		for (NSPasteboardItem *pbItem in [pasteboard pasteboardItems])
		{
			id plist = [pbItem propertyListForType: EWNoteDragType];
			COPersistentRoot *notePersistentRoot = [owner.editingContext persistentRootForUUID: [ETUUID UUIDWithString: plist]];
			ETAssert(notePersistentRoot != nil);
			
			COObject *noteRootObject = [notePersistentRoot rootObject];
			
			[tag addObject: noteRootObject];
		}
		
		[self.owner commitWithIdentifier: @"tag-note" descriptionArguments: @[tag.name != nil ? tag.name : @""]];
	}
	
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pb
{
	if ([items count] != 1)
		return NO;
	
	if (![items[0] isTag])
		return NO;
	
	NSMutableArray *pbItems = [NSMutableArray array];
    
	for (COObject *item in items)
	{
		NSPasteboardItem *pbitem = [[NSPasteboardItem alloc] init];
		[pbitem setPropertyList: [[item UUID] stringValue] forType: EWTagDragType];
		[pbItems addObject: pbitem];
	}
	
	[pb clearContents];
	return [pb writeObjects: pbItems];
}

@end

@implementation EWNoteListDataSource

@synthesize owner, tableView;

- (id) init
{
	SUPERINIT;
	oldSelection = [NSMutableSet new];
	return self;
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [[self.owner arrangedNotePersistentRoots] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSArray *objs = [self.owner arrangedNotePersistentRoots];
	if (row < 0 || row >= [objs count])
		return nil;
	
	COPersistentRoot *persistentRoot = [objs objectAtIndex: row];
	
    if ([[tableColumn identifier] isEqual: @"name"])
    {
        return persistentRoot.metadata[@"label"];
    }
    else if ([[tableColumn identifier] isEqual: @"date"])
    {
        return [NSDate date];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	COPersistentRoot *persistentRoot = [[self.owner arrangedNotePersistentRoots] objectAtIndex: row];
	
	if ([[tableColumn identifier] isEqual: @"name"])
    {
        NSMutableDictionary *md = [NSMutableDictionary dictionaryWithDictionary: persistentRoot.metadata];
		
		NSString *oldName = md[@"label"] != nil ? md[@"label"] : @"";
		NSString *newName = [object stringValue] != nil ? [object stringValue] : @"";
		
		md[@"label"] = newName;
		persistentRoot.metadata = md;
		
		[self.owner commitWithIdentifier: @"rename-note" descriptionArguments: @[oldName, newName]];
    }
}

- (void)cacheSelection
{
	[oldSelection removeAllObjects];
	NSArray *objs = [self.owner arrangedNotePersistentRoots];
	NSIndexSet *indexes = [self.tableView selectedRowIndexes];
	for (NSUInteger i = [indexes firstIndex]; i != NSNotFound; i = [indexes indexGreaterThanIndex: i])
	{
		[oldSelection addObject: objs[i]];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self cacheSelection];
	
	NSArray *rows = [self.owner arrangedNotePersistentRoots];
	if ([owner.notesTable selectedRow] >= 0 && [owner.notesTable selectedRow] < [rows count])
	{
		[owner selectNote: rows[[owner.notesTable selectedRow]]];
	}
	else
	{
		[owner selectNote: nil];
	}
}

- (void)reloadData
{
	[self.tableView reloadData];
	
	NSArray *objs = [self.owner arrangedNotePersistentRoots];
	NSMutableIndexSet *newSelectedRows = [NSMutableIndexSet new];
	for (id obj in oldSelection)
	{
		NSUInteger row = [objs indexOfObject: obj];
		if (row != NSNotFound)
		{
			[newSelectedRows addIndex: row];
		}
	}
	[self.tableView selectRowIndexes: newSelectedRows byExtendingSelection: NO];
	[self cacheSelection];
}

#pragma mark Drag & Drop

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pb
{
	NSMutableArray *pbItems = [NSMutableArray array];
    
	NSArray *objs = [self.owner arrangedNotePersistentRoots];
	
	[rowIndexes enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
		COPersistentRoot *persistentRoot = objs[idx];
		
		NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
		[item setPropertyList: [[persistentRoot UUID] stringValue] forType: EWNoteDragType];
		[pbItems addObject: item];
	}];

	[pb clearContents];
	return [pb writeObjects: pbItems];
}

@end
