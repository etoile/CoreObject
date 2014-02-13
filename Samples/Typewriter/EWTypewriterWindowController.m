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
#import "EWTagListDataSource.h"
#import "EWNoteListDataSource.h"

@implementation EWTypewriterWindowController

/**
 * Pasteboard item property list is an NSString persistent root UUID
 */
NSString * EWNoteDragType = @"org.etoile.Typewriter.Note";
NSString * EWTagDragType = @"org.etoile.Typewriter.Tag";

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
	
	// Filter by search query
	// Very slow
	
	NSString *searchQuery = [searchfield stringValue];
	[results filterUsingPredicate:
	 [NSPredicate predicateWithBlock: ^(id object, NSDictionary *bindings) {
		if ([searchQuery length] == 0)
		{
			return YES;
		}
		else
		{
			TypewriterDocument *doc = [object rootObject];
			COAttributedStringWrapper *as = [[COAttributedStringWrapper alloc] initWithBacking: doc.attrString];
			NSString *docString = [as string];
			
			NSRange range = [docString rangeOfString: searchQuery];
			return (BOOL)(range.location != NSNotFound);
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
		if ([[object representedObject] isTag])
		{
			return [object representedObject];
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
		if ([[object representedObject] isKindOfClass: [COTagGroup class]])
		{
			return [object representedObject];
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
	[tagListDataSource reloadData];	
	
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

#pragma mark - Search

- (void)search:(id)sender
{
	[noteListDataSource reloadData];
}

@end
