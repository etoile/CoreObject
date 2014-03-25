#import "EWBranchesWindowController.h"
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/Macros.h>
#import "ProjectDocument.h"
#import "EWDocumentWindowController.h"

@implementation EWBranchesWindowController

static EWBranchesWindowController *shared;

- (id)init
{
	self = [super initWithWindowNibName: @"Branches"];
    if (self) {
        shared = self;
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

+ (EWBranchesWindowController *) sharedController
{
    if (shared == nil) {
        shared = [[self alloc] init];
    }
    return shared;
}

- (void) awakeFromNib
{
}

- (EWDocumentWindowController *) inspectedWindowController
{
	return inspectedWindowController;
}

- (void) setInspectedWindowController: (EWDocumentWindowController *)aDoc
{
	if (![aDoc respondsToSelector: @selector(persistentRoot)])
		return;
	
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: COPersistentRootDidChangeNotification
                                                  object: inspectedWindowController.persistentRoot];
	
	inspectedWindowController = aDoc;
	
	[[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootMetadataDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: inspectedWindowController.persistentRoot];

    [table reloadData];
}

- (COPersistentRoot *) persistentRoot
{
	return inspectedWindowController.persistentRoot;
}

- (NSArray *) orderedBranches
{
    NSArray *unsorted = [[self.persistentRoot branches] allObjects];
    NSArray *sorted = [unsorted sortedArrayUsingDescriptors:
     A([NSSortDescriptor sortDescriptorWithKey: @"label" ascending: NO],
       [NSSortDescriptor sortDescriptorWithKey: @"UUID.stringValue" ascending: NO])];
    
    return sorted;
}

- (void) storePersistentRootMetadataDidChange: (NSNotification *)notif
{
    [table reloadData];
}

- (void) commitWithIdentifier: (NSString *)identifier descriptionArguments: (NSArray*)args
{
	identifier = [@"org.etoile.ProjectDemo." stringByAppendingString: identifier];
	
	NSMutableDictionary *metadata = [NSMutableDictionary new];
	if (args != nil)
		metadata[kCOCommitMetadataShortDescriptionArguments] = args;
		
	[[self persistentRoot] commitWithIdentifier: identifier metadata: metadata undoTrack: inspectedWindowController.undoTrack error:NULL];
}

- (COBranch *)selectedBranch
{
	if ([table selectedRow] == -1)
		return nil;
	
    COBranch *branch = [[self orderedBranches] objectAtIndex: [table selectedRow]];
    return branch;
}

/**
 * THis seems to be needed to get -delete/-deleteForward:/-deleteBackward: called
 */
- (void)keyDown:(NSEvent *)theEvent
{
	[self interpretKeyEvents: [NSArray arrayWithObject:theEvent]];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [[self.persistentRoot branches] count];;
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	COBranch *branch = [[self orderedBranches] objectAtIndex: row];
    if ([[tableColumn identifier] isEqual: @"name"])
    {
        return [branch label];
    }
    else if ([[tableColumn identifier] isEqual: @"important"])
    {
        return [[branch metadata] objectForKey: @"important"];
    }
    else if ([[tableColumn identifier] isEqual: @"checked"])
    {
        BOOL checked = [branch isCurrentBranch];
        return [NSNumber numberWithBool: checked];
    }
    return nil;
}
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    COBranch *branch = [[self orderedBranches] objectAtIndex: row];
    if ([[tableColumn identifier] isEqual: @"name"])
    {
		NSString *oldLabel = branch.label;
        [branch setLabel: object];
        [self commitWithIdentifier: @"set-branch-label" descriptionArguments: @[ oldLabel, branch.label ] ];
    }
    else if ([[tableColumn identifier] isEqual: @"important"])
    {
        ETAssert([object isKindOfClass: [NSNumber class]]);
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithDictionary: [branch metadata]];
        metadata[@"important"] = object;
        [branch setMetadata: metadata];
        [self commitWithIdentifier: @"set-branch-importance" descriptionArguments: @[ branch.label ]];
    }
    else if ([[tableColumn identifier] isEqual: @"checked"])
    {
        if ([object boolValue])
        {
            [self.persistentRoot setCurrentBranch: branch];
			[self commitWithIdentifier: @"set-branch" descriptionArguments: @[ branch.label ]];
        }
    }
}

#pragma mark - IBActions

- (IBAction)addBranch:(id)sender
{
	[inspectedWindowController branch: sender];
}

- (IBAction)deleteBranch:(id)sender
{
	COBranch *branch = [self selectedBranch];
	if (branch.isCurrentBranch)
	{
		NSLog(@"Can't delete current branch (TODO: Gray out the button)");
		return;
	}
	branch.deleted = YES;
	[self commitWithIdentifier: @"delete-branch" descriptionArguments: @[ branch.label ]];
}

- (void)deleteForward:(id)sender
{
	[self deleteBranch: sender];
}

- (void)delete:(id)sender
{
	[self deleteForward: sender];
}

- (void)deleteBackward:(id)sender
{
	[self deleteForward: sender];
}

@end
