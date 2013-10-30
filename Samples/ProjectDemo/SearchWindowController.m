#import "SearchWindowController.h"
#import "Project.h"
#import "ApplicationDelegate.h"
#import <CoreObject/CoreObject.h>

@implementation SearchWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"Search"];
	
	if (self) {
	}
	return self;
}

- (void)dealloc
{
}

- (void)awakeFromNib
{
	[table setTarget: self];
	[table setDoubleAction: @selector(doubleClick:)];
}

- (IBAction) search: (id)sender
{
	NSString *query = [(NSSearchField *)sender stringValue];
	
	COSQLiteStore *store = [[[NSApp delegate] editingContext] store];
	NSArray *results = [store searchResultsForQuery: query];
	
	searchResults = [[NSMutableArray alloc] init];
	
	for (COSearchResult *result in results)
	{
		[(NSMutableArray *)searchResults addObject: [result.persistentRoot stringValue]];
	}
	
	[table reloadData];
}

/* NSTableView Target/Action */

- (void)doubleClick: (id)sender
{

}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [searchResults count];;
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	id result = [searchResults objectAtIndex: row];
	
	return result;
//	
//    if ([[tableColumn identifier] isEqual: @"name"])
//    {
//        return [branch label];
//    }
//    else if ([[tableColumn identifier] isEqual: @"important"])
//    {
//        return [[branch metadata] objectForKey: @"important"];
//    }
//    else if ([[tableColumn identifier] isEqual: @"checked"])
//    {
//        BOOL checked = [branch isCurrentBranch];
//        return [NSNumber numberWithBool: checked];
//    }
//    return nil;
}

@end
