#import <Cocoa/Cocoa.h>
#import "OutlineItem.h"
#import "Document.h"
#import "SharingSession.h"
#import "EWDocumentWindowController.h"
#import "SharingDrawerViewController.h"
#import "EWUndoManager.h"
#import "ProjectDemoHistoryWindowController.h"

@interface EWDocumentWindowController : NSWindowController <NSWindowDelegate, EWUndoManagerDelegate>
{
	/**
	 * Is this the primary window for the persistent root?
	 * Only the primary window can track the current branch (UI decision).
	 */
	BOOL _isPrimaryWindow;
	COPersistentRoot *_persistentRoot;
	/**
	 * If nil, track the current branch.
	 */
	COBranch *_pinnedBranch;
	NSString *_windowID;
	NSDrawer *_sharingDrawer;
	SharingDrawerViewController *_sharingDrawerViewController;
	
	// UI stuff
	
	IBOutlet NSPopUpButton *branchesPopUpButton;
	IBOutlet NSButton *defaultBranchCheckBox;
	
	COUndoTrack *_undoTrack;
	
	EWUndoManager *undoManagerBridge;
	
	ProjectDemoHistoryWindowController *historyWindowController;
}

- (instancetype) initAsPrimaryWindowForPersistentRoot: (COPersistentRoot *)aPersistentRoot
											 windowID: (NSString*)windowID
										windowNibName: (NSString *)nibName;

- (instancetype) initPinnedToBranch: (COBranch *)aBranch
						   windowID: (NSString*)windowID
					  windowNibName: (NSString *)nibName;

/**
 * Unique identifier for this window
 */
@property (readonly, nonatomic, strong) NSString *windowID;

@property (readonly, nonatomic, assign) BOOL primaryWindow;

@property (readonly, nonatomic, strong) COPersistentRoot *persistentRoot;

@property (readonly, nonatomic, strong) COObjectGraphContext *objectGraphContext;

/**
 * Branch that this window is editing. nil indicates tracking the current branch.
 */
@property (readwrite, nonatomic, strong) COBranch *pinnedBranch;

/**
 * Like -pinnedBranch but instead of returning nil when we are tracking
 * the current branch, returns the current branch object.
 */
@property (readonly, nonatomic, strong) COBranch *editingBranch;

@property (readonly, nonatomic, strong) COSQLiteStore *store;
@property (readonly, nonatomic, strong) COEditingContext *editingContext;

- (Document *) documentObject;

- (COUndoTrack *) undoTrack;

- (void) persistentRootDidChange: (NSNotification *)notif;

+ (BOOL) isProjectUndo;

// UI stuff

- (IBAction)checkDefaultBranch: (id)sender;

// Subclasses override

- (void) objectGraphDidChange;

/**
 * Called when objectGraphContext is switched to a new instance. Subclasses
 * should reload everything. This is called when the branch is switched
 */
- (void) objectGraphContextDidSwitch;

/* History stuff */

- (void) commitWithIdentifier: (NSString *)identifier;

- (void) commitWithIdentifier: (NSString *)identifier descriptionArguments: (NSArray*)args;

- (void) switchToRevision: (CORevision *)aRevision;

- (void) selectiveUndo: (CORevision *)aRevision;

- (void) selectiveRedo: (CORevision *)aRevision;

- (IBAction) projectDemoUndo: (id)sender;

- (IBAction) projectDemoRedo: (id)sender;

- (IBAction) branch: (id)sender;

- (IBAction) stepBackward: (id)sender;

- (IBAction) stepForward: (id)sender;

- (IBAction) showGraphvizHistoryGraph: (id)sender;
- (IBAction) showGraphvizItemGraph: (id)sender;

- (IBAction) showDocumentHistory:(id)sender;

- (IBAction) shareWith: (id)sender;

- (IBAction) moveToTrash:(id)sender;

- (SharingSession *) sharingSession;

@end
