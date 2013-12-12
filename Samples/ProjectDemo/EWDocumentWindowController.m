#import "EWDocumentWindowController.h"
#import <CoreObject/COSQLiteStore+Debugging.h>
#import <CoreObject/COObjectGraphContext+Graphviz.h>
#import "ApplicationDelegate.h"


@interface EWDocumentWindowController ()
@end

@implementation EWDocumentWindowController

- (instancetype) initAsPrimaryWindowForPersistentRoot: (COPersistentRoot *)aPersistentRoot
											 windowID: (NSString*)windowID
										windowNibName: (NSString *)nibName
{
	NILARG_EXCEPTION_TEST(aPersistentRoot);
	NILARG_EXCEPTION_TEST(windowID);
	NILARG_EXCEPTION_TEST(nibName);
	
	self = [super initWithWindowNibName: nibName];
	_isPrimaryWindow = YES;
	_persistentRoot = aPersistentRoot;
	_pinnedBranch = nil;
	_windowID = windowID;
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(persistentRootDidChange:)
												 name: COPersistentRootDidChangeNotification
											   object: _persistentRoot];
	
	return self;
}

- (instancetype) initPinnedToBranch: (COBranch *)aBranch
						   windowID: (NSString*)windowID
					  windowNibName: (NSString *)nibName
{
	NILARG_EXCEPTION_TEST(aBranch);
	NILARG_EXCEPTION_TEST(windowID);
	NILARG_EXCEPTION_TEST(nibName);
	
	self = [super initWithWindowNibName: nibName];
	_isPrimaryWindow = NO;
	_persistentRoot = aBranch.persistentRoot;
	_pinnedBranch = aBranch;
	_windowID = windowID;
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(persistentRootDidChange:)
												 name: COPersistentRootDidChangeNotification
											   object: _persistentRoot];
	
	return self;
}

- (void)windowDidLoad
{
	[self resetBranchesMenu];
	[self resetBranchesCheckbox];
	
	_sharingDrawer = [[NSDrawer alloc] initWithContentSize: NSMakeSize(160, 100) preferredEdge: NSMaxXEdge];
	_sharingDrawerViewController = [[SharingDrawerViewController alloc] initWithParent: self];
	
	[_sharingDrawer setParentWindow: [self window]];
	[_sharingDrawer setContentView: [_sharingDrawerViewController view]];
}

@synthesize windowID = _windowID;
@synthesize primaryWindow = _isPrimaryWindow;
@synthesize persistentRoot = _persistentRoot;

- (COObjectGraphContext *) objectGraphContext
{
	if (_pinnedBranch != nil)
	{
		return [_pinnedBranch objectGraphContext];
	}
	return [_persistentRoot objectGraphContext];
}

- (COBranch *) pinnedBranch
{
	return _pinnedBranch;
}

- (void)setPinnedBranch:(COBranch *)pinnedBranch
{
	if (pinnedBranch == nil && !_isPrimaryWindow)
	{
		[NSException raise: NSGenericException
					format: @"Only the primary window can be set to track the cutrent branch "
							 "(i.e. pinnedBranch nil)"];
	}
	if (pinnedBranch != _pinnedBranch)
	{
		_pinnedBranch = pinnedBranch;
		
		[self resetBranchesMenu];
		[self resetBranchesCheckbox];
		
		[self objectGraphDidChange];
	}
}

- (COBranch *) editingBranch
{
	if (_pinnedBranch == nil)
	{
		return [_persistentRoot currentBranch];
	}
	return _pinnedBranch;
}

- (COSQLiteStore *) store
{
	return self.editingContext.store;
}

- (COEditingContext *) editingContext
{
	return self.persistentRoot.editingContext;
}

- (void) persistentRootDidChange: (NSNotification *)notif
{
	[self resetBranchesMenu];
	[self resetBranchesCheckbox];
	
	[self objectGraphDidChange];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

+ (BOOL) isProjectUndo
{
	NSString *mode = [[NSUserDefaults standardUserDefaults] valueForKey: @"UndoMode"];
	
	return (mode == nil || [mode isEqualToString: @"Project"]);
}

- (COUndoTrack *) undoTrack
{
    NSString *name = nil;
	
	if ([[self class] isProjectUndo])
	{
		name = @"org.etoile.projectdemo";
	}
	else
	{
		name = self.windowID;
	}
	
    return [COUndoTrack trackForName: name
				  withEditingContext: self.editingContext];
}

// UI Stuff

- (void) selectBranch: (id)sender
{
	COBranch *selectedBranch = [sender representedObject];
	
	NSLog(@"Switch to %@", selectedBranch);
	
	if (selectedBranch != self.editingBranch)
	{
		[self resetBranchesCheckbox];

		if (_isPrimaryWindow && (selectedBranch == _persistentRoot.currentBranch))
		{
			self.pinnedBranch = nil;
		}
		else
		{
			self.pinnedBranch = selectedBranch;
		}
	}
}

- (void) resetBranchesCheckbox
{
	if (self.editingBranch == _persistentRoot.currentBranch)
	{
		[defaultBranchCheckBox setState: NSOnState];
		[defaultBranchCheckBox setEnabled: NO];
	}
	else
	{
		[defaultBranchCheckBox setState: NSOffState];
		[defaultBranchCheckBox setEnabled: YES];
	}
}

- (void) resetBranchesMenu
{
	NSMenu *menu = [[NSMenu alloc] init];
	for (COBranch *branch in [_persistentRoot branches])
	{
		NSString *title = [branch label];
		if (title == nil)
		{
			title = [[branch UUID] stringValue];
		}
		
		NSMenuItem *item = [menu addItemWithTitle: title action: @selector(selectBranch:) keyEquivalent: @""];
		[item setRepresentedObject: branch];
		[item setTarget: self];
	}
	
	[branchesPopUpButton setMenu: menu];
	
	// Select the selected branch
	for (NSMenuItem *item in [menu itemArray])
	{
		COBranch *branch = [item representedObject];
		if (branch == self.editingBranch)
		{
			[branchesPopUpButton selectItem: item];
		}
	}
}

- (IBAction)checkDefaultBranch: (id)sender
{
	[_persistentRoot setCurrentBranch: self.editingBranch];
	[self.editingContext commitWithUndoTrack: self.undoTrack];
}

- (void) objectGraphDidChange
{
}

/* History stuff */

- (void) commitWithIdentifier: (NSString *)identifier
{
	identifier = [@"org.etoile.ProjectDemo." stringByAppendingString: identifier];
	
	[[self persistentRoot] commitWithIdentifier: identifier metadata: nil undoTrack: [self undoTrack] error:NULL];
}

- (void) switchToRevision: (CORevision *)aRevision
{
	[self.editingBranch setCurrentRevision: aRevision];
	
	[self commitWithIdentifier: @"revert"];
}

- (IBAction) projectDemoUndo: (id)sender
{
    COUndoTrack *stack = [self undoTrack];
    
    if ([stack canUndo])
    {
        [stack undo];
    }
}
- (IBAction) projectDemoRedo: (id)sender
{
    COUndoTrack *stack = [self undoTrack];
	
    if ([stack canRedo])
    {
        [stack redo];
    }
}

- (IBAction) branch: (id)sender
{
    COBranch *branch = [self.editingBranch makeBranchWithLabel: @"Untitled"];
    [self.persistentRoot setCurrentBranch: branch];
    [self.persistentRoot commit];
}

- (IBAction) stepBackward: (id)sender
{
	NSLog(@"Step back");
	
	if ([self.editingBranch canUndo])
		[self.editingBranch undo];
	
	[self commitWithIdentifier: @"step-backward"];
}

- (IBAction) stepForward: (id)sender
{
	NSLog(@"Step forward");
	
	if ([self.editingBranch canRedo])
		[self.editingBranch redo];
	
	[self commitWithIdentifier: @"step-forward"];
}

- (IBAction) showGraphvizHistoryGraph: (id)sender
{
	[[self.persistentRoot store] showGraphForPersistentRootUUID: self.persistentRoot.UUID];
}

- (IBAction) showGraphvizItemGraph: (id)sender
{
	[self.objectGraphContext showGraph];
}

- (IBAction) history: (id)sender
{
	//[(ApplicationDelegate *)[[NSApp delegate] historyController] showHistoryForDocument: doc];
}

- (IBAction) shareWith: (id)sender
{
	[_sharingDrawer toggle: sender];
	//[(ApplicationDelegate *)[[NSApplication sharedApplication] delegate] shareWithInspectorForDocument: self.doc];
}

- (IBAction)moveToTrash:(id)sender
{
	NSLog(@"Trash %@", self);
	
	self.persistentRoot.deleted = YES;
	
	NSMutableSet *docs = [[self.doc project] mutableSetValueForKey: @"documents"];
	assert([docs containsObject: self.doc]);
	[docs removeObject: self.doc];
	
	[self.editingContext commit];
	
	// FIXME: Hack
	[self close];
}

@end
