#import "EWDocumentWindowController.h"

@interface EWDocumentWindowController ()

@end

@implementation EWDocumentWindowController

- (instancetype) initWithBranch: (COBranch *)aBranch
					   windowID: (NSString*)windowID
				  windowNibName: (NSString *)nibName
{
	self = [super initWithWindowNibName: nibName];
	self.windowID = windowID;
	self.editingBranch = aBranch;
	return self;
}

- (COSQLiteStore *) store
{
	return self.editingContext.store;
}

- (COEditingContext *) editingContext
{
	return self.persistentRoot.editingContext;
}

- (COPersistentRoot *) persistentRoot
{
	return self.editingBranch.persistentRoot;
}

- (COBranch *) editingBranch
{
	return _editingBranch;
}

- (void)setEditingBranch:(COBranch *)editingBranch
{
	if (_editingBranch != nil)
	{
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: COPersistentRootDidChangeNotification
													  object: [_editingBranch persistentRoot]];
	}
	
	_editingBranch = editingBranch;

	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(persistentRootDidChange:)
												 name: COPersistentRootDidChangeNotification
											   object: [_editingBranch persistentRoot]];
}

- (void) persistentRootDidChange: (NSNotification *)notif
{
	[self doesNotRecognizeSelector: _cmd];
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

@end
