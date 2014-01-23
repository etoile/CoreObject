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
	[tableView setMenu: [self tableMenu]];
}

#pragma mark - Context menu

- (NSMenu *) tableMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle: @""];
	[menu addItemWithTitle: @"Selective Undo" action: @selector(selectiveUndo:) keyEquivalent: @""];
	[menu addItemWithTitle: @"Selective Apply" action: @selector(selectiveApply:) keyEquivalent: @""];
	[menu addItem: [NSMenuItem separatorItem]];
	[menu addItemWithTitle: @"Switch To Commit" action: @selector(switchToCommit:) keyEquivalent: @""];
	
	for (NSMenuItem *item in [menu itemArray])
	{
		[item setTarget: self];
	}
	
	return menu;
}

- (CORevision *) clickedRevision
{
	return [graphRenderer revisionAtIndex: [tableView clickedRow]];
}

- (void) selectiveUndo: (id)sender
{
	CORevision *revision = [self clickedRevision];
}

- (void) selectiveApply: (id)sender
{
	CORevision *revision = [self clickedRevision];
}

- (void) switchToCommit: (id)sender
{
	CORevision *revision = [self clickedRevision];

	[wc switchToRevision: revision];
}

- (void) setInspectedWindowController: (EWDocumentWindowController *)aDoc
{
	wc = aDoc;
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

- (void) windowDidLoad
{
	NSLog(@"%@: -windowDidLoad", self);
	[self updateTable];
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
