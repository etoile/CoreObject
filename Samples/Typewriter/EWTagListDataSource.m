/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import "EWTagListDataSource.h"
#import "EWTypewriterWindowController.h"

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
	
	if ([item isTag])
	{
		[self.owner commitWithIdentifier: @"rename-tag" descriptionArguments: @[oldName, newName]];
	}
	else
	{
		[self.owner commitWithIdentifier: @"rename-tag-group" descriptionArguments: @[oldName, newName]];
	}
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

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return [item isKindOfClass: [COTagGroup class]];
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
