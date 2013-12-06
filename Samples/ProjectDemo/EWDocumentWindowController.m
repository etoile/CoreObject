#import "EWDocumentWindowController.h"

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

- (void)windowDidLoad
{
	[self resetBranchesMenu];
	[self resetBranchesCheckbox];
}

- (IBAction)checkDefaultBranch: (id)sender
{
	[_persistentRoot setCurrentBranch: self.editingBranch];
	[self.editingContext commitWithUndoTrack: self.undoTrack];
}

- (void) objectGraphDidChange
{
}

@end
