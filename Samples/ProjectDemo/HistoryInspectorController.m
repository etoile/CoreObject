#import "HistoryInspectorController.h"
#import <CoreObject/CoreObject.h>

@implementation HistoryInspectorController
#if 0
- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(didCommit:)
												 name:COStoreDidCommitNotification 
											   object:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
} 

- (void)setContext: (COEditingContext*)ctx
{
	context = ctx;
}
//
//static void collectNodes(COHistoryNode *node, NSMutableArray *collection)
//{
//	[collection addObject: node];
//	for (COHistoryNode *children in [node branches])
//	{
//		collectNodes(children, collection);
//	}
//}

- (NSArray*)allHistoryGraphNodes
{
//	COHistoryNode *node = [context baseHistoryGraphNode];
//	while ([node parent] != nil)
//	{
//		if ([node isEqual: [node parent]])
//		{
//			assert(0); 
//		}
//		node = [node parent];
//	}
//	
//	NSMutableArray *allNodes = [NSMutableArray array];
//	if (node != nil)
//		collectNodes(node, allNodes);
//	
//	NSArray *sortedArray = [allNodes sortedArrayUsingComparator: ^(id obj1, id obj2) {
//		NSDate *d1 = [[obj1 properties] objectForKey: kCODateHistoryGraphNodeProperty];
//		NSDate *d2 = [[obj2 properties] objectForKey: kCODateHistoryGraphNodeProperty];
//		return (NSComparisonResult)[d1 compare: d2];
//	}];
	
	return [NSArray array];
}

/* COStoreCoordinator notification */

- (void)didCommit: (NSNotification*)notif
{
	NSLog(@"History inspector notified of commit");
	[historyInspectorTable reloadData];
	[historyInspectorTable scrollRowToVisible: [historyInspectorTable numberOfRows] - 1];
}

/* helper methods */

- (COHistoryNode*)selectedRowHistoryNode
{
	return [[self allHistoryGraphNodes] objectAtIndex: [historyInspectorTable selectedRow]];
}

/* table view delegate */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[self allHistoryGraphNodes] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	COHistoryNode *node = [[self allHistoryGraphNodes] objectAtIndex: rowIndex];
	
	if ([[aTableColumn identifier] isEqualToString: @"date"])
	{
		return [[node properties] objectForKey: kCODateHistoryGraphNodeProperty];
	}
	else if ([[aTableColumn identifier] isEqualToString: @"shortdescription"])
	{
		return [[node properties] objectForKey: kCOShortDescriptionHistoryGraphNodeProperty];
	}
	else if ([[aTableColumn identifier] isEqualToString: @"type"])
	{
		return [[node properties] objectForKey: kCOTypeHistoryGraphNodeProperty];
	}
	else if ([[aTableColumn identifier] isEqualToString: @"description"])
	{
		return [[node properties] objectForKey: kCODescriptionHistoryGraphNodeProperty];
	}
	else if ([[aTableColumn identifier] isEqualToString: @"uuid"])
	{
		return [[node uuid] stringValue];
	}
	return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notif
{
	COHistoryNode *node = [self selectedRowHistoryNode];
	[textDisplay setString: [node detailedDescription]];
}

/* actions */

- (IBAction)revertTo: (id)sender
{
	COHistoryNode *selected = [self selectedRowHistoryNode];
	NSLog(@"Reverting to %@", selected);
	[context rollbackToRevision: selected];
	
	[context commitWithType: kCOTypeMinorEdit
		   shortDescription: @"Revert"
			longDescription: [NSString stringWithFormat: @"Revert to revision %@", [[selected uuid] stringValue]]];
}
- (IBAction)selectiveUndo: (id)sender
{
	COHistoryNode *selected = [self selectedRowHistoryNode];
	NSLog(@"Undoing %@", selected);
	[context selectiveUndoChangesMadeInRevision: selected];
	
	[context commitWithType: kCOTypeMinorEdit
		   shortDescription: @"Selective Undo"
			longDescription: [NSString stringWithFormat: @"Undo changes made in revision %@", [[selected uuid] stringValue]]];
}

- (IBAction)showProjectHistory: (id)sender
{
	[historyInspectorWindow makeKeyAndOrderFront: nil];
	[historyInspectorWindow setTitle: @"Project History"];
}

- (void)showHistoryForDocument: (Document*)aDocument
{
	[historyInspectorWindow makeKeyAndOrderFront: nil];	
	[historyInspectorWindow setTitle: 
	 [NSString stringWithFormat: @"Document %@ History", [aDocument uuid]]];
}
#endif
@end
