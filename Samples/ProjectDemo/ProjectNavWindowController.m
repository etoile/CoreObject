#import "ProjectNavWindowController.h"
#import "Project.h"
#import "ApplicationDelegate.h"

@implementation ProjectNavWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"ProjectNav"];
	
	if (self) {
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (NSArray *) projectsSorted
{
	NSArray *unsorted = [[(ApplicationDelegate *)[NSApp delegate] projects] allObjects];
	
	return [unsorted sortedArrayUsingDescriptors:
	 @[[[NSSortDescriptor alloc] initWithKey:@"name" ascending: YES]]];
}

- (void)awakeFromNib
{
	// Hmm.. we really need to listen for persistent root creation
	// and update our outline view.
	
	[outline setTarget: self];
	[outline setDoubleAction: @selector(doubleClick:)];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(editingContextChanged:)
												 name: COEditingContextDidChangeNotification
											   object: [[NSApp delegate] editingContext]];
}

- (void) editingContextChanged: (NSNotification *)notif
{
	[outline reloadData];
}

/* NSOutlineView Target/Action */

- (void)doubleClick: (id)sender
{
	if (sender == outline)
	{
		id item = [outline itemAtRow: [outline selectedRow]];
		
		COPersistentRoot *proot = [item persistentRoot];
		NSLog(@"Double click: %@", proot);
		
		[(ApplicationDelegate *)[NSApp delegate] openDocumentWindowForPersistentRoot: proot];
	}
}

/* NSOutlineView data source */

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item
{
	if (nil == item) {
		return [[self projectsSorted] objectAtIndex: index];
	}
	
	Project *project = item;
	
	return [[item documentsSorted] objectAtIndex: index];
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item
{
	return [self outlineView: outlineView numberOfChildrenOfItem: item] > 0;
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item
{
	if (nil == item) {
		return [[self projectsSorted] count];
	}
	
	if ([item isKindOfClass: [Project class]])
	{
		return [[item documents] count];
	}
	
	return 0;
}

- (id) outlineView: (NSOutlineView *)outlineView objectValueForTableColumn: (NSTableColumn *)column byItem: (id)item
{
	if (nil == item) { return nil; }
	
	if ([item isKindOfClass: [Document class]])
	{
		return [[item persistentRoot] name];
	}
	return @"?";
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	
	[item setValue: object forProperty: @"name"];
	[[[NSApp delegate] editingContext] commit];
//	if (nil == item) { item = [self rootObject]; }
//	
//	if ([item isKindOfClass: [OutlineItem class]])
//	{
//		NSString *oldLabel = [[item label] retain];
//		[item setLabel: object];
//		
//		[self commitWithType: @"kCOTypeMinorEdit"
//			shortDescription: @"Edit Label"
//			 longDescription: [NSString stringWithFormat: @"Edit label from %@ to %@", oldLabel, [item label]]];
//		
//		[oldLabel release];
//	}
}

@end
