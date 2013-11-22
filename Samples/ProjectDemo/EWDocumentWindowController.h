#import <Cocoa/Cocoa.h>
#import "OutlineItem.h"
#import "Document.h"
#import "SharingSession.h"
#import "EWDocumentWindowController.h"

@interface EWDocumentWindowController : NSWindowController
{
	COBranch *_editingBranch;
	NSString *_windowID;
}

- (instancetype) initWithBranch: (COBranch *)aBranch
					   windowID: (NSString*)windowID
				  windowNibName: (NSString *)nibName;

/**
 * Unique identifier for this window...
 */
@property (readwrite, nonatomic, strong) NSString *windowID;
/**
 * Branch that this window is editing.
 *
 * Note that we don't use COPersistentRoot.editingBranch but rather
 * this property allows one editing branch per window.
 */
@property (readwrite, nonatomic, strong) COBranch *editingBranch;

@property (readonly, nonatomic, strong) COSQLiteStore *store;
@property (readonly, nonatomic, strong) COEditingContext *editingContext;
@property (readonly, nonatomic, strong) COPersistentRoot *persistentRoot;
@property (readonly, nonatomic, strong) Document *doc;

- (COUndoTrack *) undoTrack;

- (void) persistentRootDidChange: (NSNotification *)notif;

+ (BOOL) isProjectUndo;

@end
