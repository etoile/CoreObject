#import "TagWindowController.h"
#import "Tag.h"
#import "ApplicationDelegate.h"

@implementation TagWindowController

- (id)init
{
	self = [super init];

	return self;
}

- (void) show: (id)sender
{
	[window makeKeyAndOrderFront: nil];
	[table reloadData];
}

- (void) setDocument: (Document*)doc
{
	document = doc;
	[window setTitle: [NSString stringWithFormat: @"Tags for %@", [doc documentName]]];
	[table reloadData];
}

- (NSArray *)tagsArray
{
	NSArray *tagsArray = [[document tags] allObjects];
	if (tagsArray == nil)
	{
		tagsArray = [NSArray array];
	}
	
	tagsArray = [tagsArray sortedArrayUsingDescriptors: A([NSSortDescriptor sortDescriptorWithKey: @"label" ascending: YES])];
	return tagsArray;
}


- (IBAction) addTag: (id)sender
{
	if (document == nil) return;
	
	if ([tagNameField stringValue] != nil && ![[tagNameField stringValue] isEqual: @""])
	{
		NSString *label = [tagNameField stringValue];
		
		COEditingContext *ctx = [[NSApp delegate] editingContext];
		
		// see if there is already a tag with this name
		Tag *found = nil;
		for (Tag *tag in [[[NSApp delegate] project] tags])
		{
			if ([[tag label] isEqual: label])
			{
				found = tag;
				break;
			}
		}
		
		Tag *newTag;
		if (found != nil)
		{
			// reuse an existing tag object
			newTag = found;
			NSLog(@"Reusing tag %@", newTag);
		}
		else
		{
			// create a new tag
			newTag = [[[Tag alloc] initWithContext: ctx] autorelease];
			[newTag setLabel: label];
			[[[NSApp delegate] project] addTag: newTag];
			NSLog(@"Creating new tag %@", newTag);
		}
		
		[document addTag: newTag];
		
		[ctx commitWithType:kCOTypeMinorEdit
		   shortDescription:@"Add tag"
			longDescription:[NSString stringWithFormat: @"Add tag '%@' to document '%@'", label, [document documentName]]];
		
		[tagNameField setStringValue: @""];
		[table reloadData];
	}
}

- (IBAction) removeTag: (id)sender
{
	if (document == nil) return;
	
	NSInteger item = [table selectedRow];
	if (item >= 0 && item < [[self tagsArray] count])
	{
		Tag *tagToRemove = [[self tagsArray] objectAtIndex: item];
		
		COEditingContext *ctx = [[NSApp delegate] editingContext];
		[document removeTag: tagToRemove];

		[ctx commitWithType:kCOTypeMinorEdit
		   shortDescription:@"Remove tag"
			longDescription:[NSString stringWithFormat: @"Remove tag '%@' from document '%@'", [tagToRemove label], [document documentName]]];
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
