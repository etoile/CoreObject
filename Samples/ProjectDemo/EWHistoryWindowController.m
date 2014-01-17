#import "EWHistoryWindowController.h"
#import "Document.h"
#import <CoreObject/CoreObject.h>
#import "EWGraphRenderer.h"

@implementation EWHistoryWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"History"];
    if (self) {
    }
    return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: COPersistentRootDidChangeNotification
                                                  object: persistentRoot];
}

+ (EWHistoryWindowController *) sharedController
{
    static EWHistoryWindowController *shared;
    if (shared == nil) {
        shared = [[self alloc] init];
    }
    return shared;
}

- (void) awakeFromNib
{
}

- (void) setInspectedWindowController: (EWDocumentWindowController *)aDoc
{
	[self setPersistentRoot: [aDoc persistentRoot]];
}

- (void) storePersistentRootMetadataDidChange: (NSNotification *)notif
{
    [self updateTable];
}

- (void) setPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: COPersistentRootDidChangeNotification
                                                  object: persistentRoot];
    
    persistentRoot = aPersistentRoot;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootMetadataDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: persistentRoot];
	
    //NSLog(@"current branch: %@ has %d commits.g v %@", branch, (int)[[branch allCommits] count], graphView_);
    
    [self updateTable];
}

- (void) updateTable
{
	NSLog(@"history window: updating: %@", persistentRoot);
	[graphRenderer updateWithProot: persistentRoot];
	[tableView reloadData];
}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [graphRenderer count];
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	CORevision *revision = [graphRenderer revisionAtIndex: row];
	
    if ([[tableColumn identifier] isEqual: @"graph"])
    {
        return @(row);
    }
    else if ([[tableColumn identifier] isEqual: @"description"])
    {
        return [revision localizedShortDescription];
    }
    else if ([[tableColumn identifier] isEqual: @"author"])
    {
		return [revision metadata][@"username"];
    }
	else if ([[tableColumn identifier] isEqual: @"date"])
	{
		return [revision date];
	}
	
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
}

@end
