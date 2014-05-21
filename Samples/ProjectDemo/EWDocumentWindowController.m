#import "EWDocumentWindowController.h"
#import <CoreObject/COSQLiteStore+Graphviz.h>
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
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextDidChange:)
												 name: COObjectGraphContextObjectsDidChangeNotification
											   object: self.objectGraphContext];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(defaultsChanged:)
												 name: NSUserDefaultsDidChangeNotification
											   object: nil];
	
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
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(objectGraphContextDidChange:)
												 name: COObjectGraphContextObjectsDidChangeNotification
											   object: self.objectGraphContext];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(defaultsChanged:)
												 name: NSUserDefaultsDidChangeNotification
											   object: nil];
	
	return self;
}

- (void)windowDidLoad
{
	undoManagerBridge = [[EWUndoManager alloc] init];
	[undoManagerBridge setDelegate: self];
	
	[self resetBranchesMenu];
	[self resetBranchesCheckbox];
	[self resetTitle];

	[self objectGraphDidChange];

	_sharingDrawer = [[NSDrawer alloc] initWithContentSize: NSMakeSize(280, 100) preferredEdge: NSMaxXEdge];
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
		[[NSNotificationCenter defaultCenter] removeObserver: self name: COObjectGraphContextObjectsDidChangeNotification object: _pinnedBranch];
		
		_pinnedBranch = pinnedBranch;
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(objectGraphContextDidChange:)
													 name: COObjectGraphContextObjectsDidChangeNotification
												   object: self.objectGraphContext];
		
		[self resetBranchesMenu];
		[self resetBranchesCheckbox];
		
		NSLog(@"setPinnedBranch: called");
		
		[self objectGraphContextDidSwitch];
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
	[self resetTitle];
	
	[self objectGraphDidChange];
}

- (void) objectGraphContextDidChange: (NSNotification *)notif
{
	NSLog(@"object graph context did change: %@", [notif userInfo]);
	
	
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
	if (_undoTrack == nil)
	{
		NSString *name = self.windowID;

		if ([[self class] isProjectUndo])
		{
			name = @"org.etoile.projectdemo";
		}
		
		_undoTrack = [COUndoTrack trackForName: name
							withEditingContext: self.editingContext];
		_undoTrack.customRevisionMetadata = @{ @"username" : NSFullUserName() };
	}
	return _undoTrack;
}

- (void) defaultsChanged: (NSNotification*)notif
{
	// Re-cache undo track
	_undoTrack = nil;
	[self undoTrack];
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

- (Document *) documentObject
{
	Document *document = [self.objectGraphContext rootObject];
	if (![document isKindOfClass: [Document class]])
	{
		NSLog(@"ERROR: -[%@ %@]: Expected root object to be a Document instance, instead it is: %@",
			  NSStringFromClass([self class]),
			  NSStringFromSelector(_cmd),
			  document);
		return nil;
	}
	return document;
}

- (void) resetTitle
{
	NSString *title = @"";
	if (self.persistentRoot.name != nil)
	{
		title = self.persistentRoot.name;
	}
	[[self window] setTitle: title];
}

- (IBAction)checkDefaultBranch: (id)sender
{
	[_persistentRoot setCurrentBranch: self.editingBranch];
	[self.editingContext commitWithUndoTrack: self.undoTrack];
}

- (void) objectGraphDidChange
{
}

- (void) objectGraphContextDidSwitch
{
	// Dummy implementation.
	[self objectGraphDidChange];
}

/* History stuff */

- (void) commitWithIdentifier: (NSString *)identifier descriptionArguments: (NSArray*)args
{
	identifier = [@"org.etoile.ProjectDemo." stringByAppendingString: identifier];
	
	NSMutableDictionary *metadata = [NSMutableDictionary new];
	if (args != nil)
		metadata[kCOCommitMetadataShortDescriptionArguments] = args;
	
//	XMPPController *xmppController = [XMPPController sharedInstance];
//	if (xmppController.username != nil)
//		metadata[@"username"] = xmppController.username;
	
	metadata[@"username"] = NSFullUserName();
	
	[[self persistentRoot] commitWithIdentifier: identifier metadata: metadata undoTrack: [self undoTrack] error:NULL];
}

- (void) commitWithIdentifier: (NSString *)identifier
{
	[self commitWithIdentifier: identifier descriptionArguments: nil];
}

- (void) switchToRevision: (CORevision *)aRevision
{
	[self.editingBranch setCurrentRevision: aRevision];
	
	[self commitWithIdentifier: @"revert"];
}

- (void) selectiveUndo: (CORevision *)aRevision
{
	
}

- (void) selectiveRedo: (CORevision *)aRevision
{
	
}

#pragma mark - NSWindowDelegate

-(NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
	NSLog(@"asked for undo manager");
	return (NSUndoManager *)undoManagerBridge;
}

#pragma mark - EWUndoManagerDelegate

- (void) undo
{
	[[self undoTrack] undo];
}

- (void) redo
{
	[[self undoTrack] redo];
}

- (BOOL) canUndo
{
	return [[self undoTrack] canUndo];
}

- (BOOL) canRedo
{
	return [[self undoTrack] canRedo];
}

- (NSString *) undoMenuItemTitle
{
	return [[self undoTrack] undoMenuItemTitle];
}
- (NSString *) redoMenuItemTitle
{
	return [[self undoTrack] redoMenuItemTitle];
}

#pragma mark -

- (IBAction)showDocumentHistory:(id)sender
{
	if (historyWindowController != nil)
	{
		[historyWindowController close];
	}
	
	historyWindowController = [[ProjectDemoHistoryWindowController alloc] initWithInspectedPersistentRoot: _persistentRoot
																								undoTrack: [self undoTrack]];
	[historyWindowController showWindow: nil];
}

- (IBAction) branch: (id)sender
{
    COBranch *branch = [self.editingBranch makeBranchWithLabel: @"Untitled"];
    [self.persistentRoot setCurrentBranch: branch];
    [self commitWithIdentifier: @"add-branch" descriptionArguments: @[ branch.label ]];
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
	
	NSSet *projects = [[self documentObject] projects];
	
	if (projects == nil || [projects isEmpty])
	{
		NSLog(@"Broken cross-ref");
		[[self documentObject] projects];
	}
	
	for (Project *project in projects)
	{
		NSMutableSet *docs = [project mutableSetValueForKey: @"documents"];
		assert([docs containsObject: [self documentObject]]);
		[docs removeObject: [self documentObject]];
	}
	[self.editingContext commit];
	
	
	// FIXME: Hack
	[self close];
}

- (IBAction)rename:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText: @"Rename document"
                                     defaultButton: @"OK"
                                   alternateButton: @"Cancel"
                                       otherButton: nil
                         informativeTextWithFormat: @""];
	
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue: self.persistentRoot.name];
    [alert setAccessoryView:input];
	
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        
		NSString *oldDocName = self.persistentRoot.name;
		self.persistentRoot.name = [input stringValue];
				
		[self commitWithIdentifier: @"rename-document"
			  descriptionArguments: @[oldDocName, self.persistentRoot.name]];
    }
}

- (SharingSession *) sharingSession
{
	return [[XMPPController sharedInstance] sharingSessionForBranch: self.editingBranch];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    SEL theAction = [anItem action];

	if (theAction == @selector(stepBackward:)
		|| theAction == @selector(stepForward:))
	{
		return self.editingBranch.supportsRevert;
	}
	
	return [self respondsToSelector: theAction];
}

@end
