#import "TagWindowController.h"


@implementation TagWindowController

- (id)init
{
	self = [super init];
	tags = [[NSMutableArray alloc] init];
	return self;
}

- (NSArray *)tagsArray
{
	return tags;
}


- (IBAction) addTag: (id)sender
{
	if ([tagNameField stringValue] != nil && ![[tagNameField stringValue] isEqual: @""])
	{
		[tags addObject: [tagNameField stringValue]];
		[tagNameField setStringValue: @""];
		[table reloadData];
	}
}

- (IBAction) removeTag: (id)sender
{
	NSInteger item = [table selectedRow];
	if (item >= 0 && item < [[self tagsArray] count])
	{
		[tags removeObjectAtIndex: item];
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
	return [[self tagsArray] objectAtIndex: row];
}

@end
