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
@property (nonatomic, weak) EWTypewriterWindowController *owner;
@property (nonatomic, strong) NSOutlineView *outlineView;
@end

@interface EWNoteListDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, weak) EWTypewriterWindowController *owner;
@property (nonatomic, strong) NSTableView *tableView;
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
	[results sortUsingDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: @"metadata.label" ascending: YES]]];
	
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
	
	[tagsOutline registerForDraggedTypes: @[EWNoteDragType]];
	
	// Text view setup
	
	[textView setDelegate: self];
	
	// Observe editing context changes
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(editingContextChanged:)
												 name: COEditingContextDidChangeNotification
											   object: self.editingContext];
}

#pragma mark - Notification methods

- (void) editingContextChanged: (NSNotification *)notif
{
	[tagsOutline reloadData];
	[notesTable reloadData];
}

#pragma mark - IBActions

- (IBAction) addTag:(id)sender
{
	COTagGroup *defaultTagGroup = [self defaultTagGroup];
	
	COTag *newTag = [[COTag alloc] initWithObjectGraphContext: [[[self document] libraryPersistentRoot] objectGraphContext]];
	newTag.name = @"New Tag";
	[defaultTagGroup addObject: newTag];
	
	[self commitWithIdentifier: @"add-tag" descriptionArguments: @[]];
	[tagsOutline reloadData];
}

- (IBAction) addNote:(id)sender
{
	[self.editingContext insertNewPersistentRootWithEntityName: @"TypewriterDocument"];
	[self commitWithIdentifier: @"add-note" descriptionArguments: @[]];
	[notesTable reloadData];
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
		[notesTable reloadData];
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
			[tagsOutline reloadData];
		}
	}
}

#pragma mark - Private

- (void) selectNote: (COPersistentRoot *)aNote
{
	selectedNote = aNote;
	NSLog(@"Select %@", selectedNote);
	
	TypewriterDocument *doc = [selectedNote rootObject];
	
	[textStorage removeLayoutManager: [textView layoutManager]];
	textStorage = nil;
	
	textStorage = [[COAttributedStringWrapper alloc] initWithBacking: [doc attrString]];
	[textStorage addLayoutManager: [textView layoutManager]];
	[textStorage setDelegate: self];
	
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
	
	[notesTable reloadData];
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

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[self.owner selectTag: nil];
}

#pragma mark Drag & Drop

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	if (![item isTag])
	{
		return NSDragOperationNone;
	}
    
	return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
	NSPasteboard *pasteboard = [info draggingPasteboard];
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
	
	[self.owner commitWithIdentifier: @"tag-note" descriptionArguments: @[]];
	
	return YES;
}

@end

@implementation EWNoteListDataSource

@synthesize owner, tableView;

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

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSArray *rows = [self.owner arrangedNotePersistentRoots];
	if ([owner.notesTable selectedRow] >= 0 && [owner.notesTable selectedRow] < [rows count])
	{
		[owner selectNote: rows[[owner.notesTable selectedRow]]];
	}
}

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
