#import "TagWindowController.h"
#import "Tag.h"
#import "ApplicationDelegate.h"

@implementation TagWindowController

- (id)init
{
	self = [super init];

	return self;
}

- (NSArray *)tagsArray
{
	NSArray *tagsArray = [[[[NSApp delegate] project] tags] allObjects];
	tagsArray = [tagsArray sortedArrayUsingDescriptors: A([NSSortDescriptor sortDescriptorWithKey: @"label" ascending: YES])];
	return tagsArray;
}


- (IBAction) addTag: (id)sender
{
	if ([tagNameField stringValue] != nil && ![[tagNameField stringValue] isEqual: @""])
	{
		NSString *label = [tagNameField stringValue];
		
		COEditingContext *ctx = [[NSApp delegate] editingContext];
		Tag *newTag = [[[Tag alloc] initWithContext: ctx] autorelease];
		[newTag setLabel: label];
		[[[NSApp delegate] project] addTag: newTag];
		
		[ctx commit];
		
		[tagNameField setStringValue: @""];
		[table reloadData];
	}
}

- (IBAction) removeTag: (id)sender
{
	NSInteger item = [table selectedRow];
	if (item >= 0 && item < [[self tagsArray] count])
	{
		Tag *tagToRemove = [[self tagsArray] objectAtIndex: item];
		
		COEditingContext *ctx = [[NSApp delegate] editingContext];
		[[[NSApp delegate] project] removeTag: tagToRemove];
		[ctx commit];
	}
	[table reloadData];
}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [[self tagsArray] count];
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return [[[self tagsArray] objectAtIndex: row] label];
}

@end
