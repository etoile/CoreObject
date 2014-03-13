/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import "EWNoteListDataSource.h"
#import "EWTypewriterWindowController.h"
#import "EWTableView.h"
#import "TypewriterDocument.h"

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
        return persistentRoot.modificationDate;
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
		
		[self.owner commitChangesInBlock: ^{
			persistentRoot.metadata = md;
		} withIdentifier: @"rename-note" descriptionArguments: @[oldName, newName]];
    }
}

- (void)cacheSelection
{
	[oldSelection removeAllObjects];
	NSArray *objs = [self.owner arrangedNotePersistentRoots];
	NSIndexSet *indexes = [self.tableView selectedRowIndexes];
	for (NSUInteger i = [indexes firstIndex]; i != NSNotFound; i = [indexes indexGreaterThanIndex: i])
	{
		[oldSelection addObject: [objs[i] UUID]];
	}
}

- (void) setNextSelection: (ETUUID *)aUUID
{
	nextSelection = aUUID;
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
	
	NSSet *uuidsToSelect = nextSelection != nil ? S(nextSelection) : oldSelection;
	nextSelection = nil;
	
	for (ETUUID *uuid in uuidsToSelect)
	{
		NSInteger row = 0;
		for (COPersistentRoot *proot in objs)
		{
			if ([proot.UUID isEqual: uuid])
			{
				[newSelectedRows addIndex: row];
			}
			row++;
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

#pragma mark - Menu

- (NSMenu *) tableView: (EWTableView *)aTableView menuForEvent: (NSEvent *)anEvent defaultMenu: (NSMenu *)aMenu
{
	NSMenu *menu = [aMenu copy];
	
	NSArray *proots = [self.owner selectedNotePersistentRoots];
	if ([proots count] == 1)
	{
		TypewriterDocument *rootObject = [proots[0] rootObject];
		NSSet *tags = [rootObject tags];
		if ([tags count] > 0)
		{
			NSInteger insertionIndex = 2;
			[menu insertItem: [NSMenuItem separatorItem] atIndex: insertionIndex++];
			
			for (COTag *tag in tags)
			{
				NSMenuItem *item = [menu insertItemWithTitle: [NSString stringWithFormat: @"Remove tag \"%@\"", [tag name]]
													  action: @selector(removeTagFromNote:)
											   keyEquivalent: @""
													 atIndex: insertionIndex++];
				[item setRepresentedObject: tag];
			}
		}
	}
	
	return menu;
}

@end
