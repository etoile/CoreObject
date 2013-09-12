#import "EWHistoryGraphView.h"
#import "EWGraphRenderer.h"
#import <EtoileFoundation/Macros.h>

#import "EWDocument.h"

#import "COBranch+Private.h"

@implementation EWHistoryGraphView

- (id) initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        trackingRects = [[NSMutableArray alloc] init];
    }
    
    return self;
}
- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        trackingRects = [[NSMutableArray alloc] init];
    }
    return self;
}


- (NSSet *) revisionIDsOnBranch: (COBranch *)aBranch
{
    NSMutableSet *revisionIDs = [NSMutableSet set];
    if (![aBranch isBranchUncommitted])
    {
        CORevision *head = [aBranch currentRevision];
        CORevision *tail = [aBranch parentRevision];
        
        ETAssert(head != nil);
        ETAssert(tail != nil);
        
        CORevision *current = head;
        while (![current isEqual: tail])
        {
            [revisionIDs addObject: [current revisionID]];
            current = [current parentRevision];
            
            ETAssert(current != nil);
        }
        
        [revisionIDs addObject: [current revisionID]];
    }
    return revisionIDs;
}

- (void) setPersistentRoot: (COPersistentRoot *)proot
                    branch: (COBranch*)aBranch
                     store: (COSQLiteStore*)aStore
{
    // Array of CORevisionID
    NSMutableSet *allCommitsOnAllBranches = [NSMutableSet set];

    for (COBranch *branch in [proot branches])
    {
        [allCommitsOnAllBranches unionSet: [self revisionIDsOnBranch: branch]];
    }
    
    [self setGraphRenderer: [[EWGraphRenderer alloc] initWithCommits: allCommitsOnAllBranches
                                                        branchCommits: [self revisionIDsOnBranch: aBranch]
                                                        currentCommit: [[aBranch currentRevision] revisionID]
                                                                store: aStore]];
}

- (void) drawRect:(NSRect)dirtyRect
{
    [NSGraphicsContext saveGraphicsState];
    
    [[NSColor whiteColor] set];
    NSRectFill([self bounds]);
    
	if (graphRenderer != nil)
	{        
        [graphRenderer drawWithHighlightedCommit: mouseoverCommit];
	}
    
    [NSGraphicsContext restoreGraphicsState];
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
//	COSQLiteStore *store = [graphRenderer store];
	CORevisionID *commit = [graphRenderer commitAtPoint: point];
	
	if (commit == nil)
	{
		return nil;
	}
	
	NSMutableString *desc = [NSMutableString string];
	
    [desc appendString: @"todo"];
    
//	[desc appendFormat: @"%@", commit];
//	
//	COUUID *parent = [store parentForCommit: commit];
//	if (nil != parent)
//	{
//		COSubtree *before = [store treeForCommit: parent];
//		COSubtree *after = [store treeForCommit: commit];
//		COSubtreeDiff *diff = [COSubtreeDiff diffSubtree: before withSubtree: after sourceIdentifier: @""];
//		
//		[desc appendFormat: @"\n\n%@", diff];
//	}
	
	return desc;
}

- (void) setGraphRenderer: (EWGraphRenderer *)aRenderer
{
    assert(trackingRects != nil);
    for (NSNumber *number in trackingRects)
    {
        NSLog(@"Removing tracking rect %ld", [number integerValue]);
        [self removeTrackingRect: [number integerValue]];
    }
    [trackingRects removeAllObjects];
    
	graphRenderer =  aRenderer;
	
	//NSLog(@"Graph renderer size: %@", NSStringFromSize([graphRenderer size]));
	
	[self setFrameSize: [graphRenderer size]];
	[self setNeedsDisplay: YES];
    
    [[self window] invalidateCursorRectsForView: self];
}

-(void)resetCursorRects
{
    [super resetCursorRects];
    
	// Update tooltips
	
	[self removeAllToolTips];
    
	for (CORevisionID *commit in [graphRenderer commits])
	{
		NSRect r = [graphRenderer rectForCommit: commit];
		[self addToolTipRect:r owner:self userData:(__bridge void *)(commit)];
        
        // Does not retain userData. We must be careful that we keep
        // the objects returned by [graphRenderer commits] retained until the
        // tracking rect is cleared.
        
        NSInteger tag = [self addTrackingRect:r owner:self userData:(__bridge void *)(commit) assumeInside:NO];
        [trackingRects addObject: [NSNumber numberWithInteger: tag]];
        
        NSLog(@"Adding tracking rect %ld", tag);
	}
}

- (void) setCurrentCommit: (ETUUID *)aCommit
{
	[self setNeedsDisplay: YES];
}

- (NSMenu *) menuForEvent: (NSEvent *)theEvent
{
    NSPoint pt = [self convertPoint: [theEvent locationInWindow] 
						   fromView: nil];
	
    CORevisionID *commit = [graphRenderer commitAtPoint: pt];
	
	if (nil != commit)
	{
		NSMenu *menu = [[NSMenu alloc] initWithTitle: @""];

//		{
//			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle: @"Diff with Current Commit" 
//														   action: @selector(diffCommits:) 
//													keyEquivalent: @""] autorelease];
//			[item setRepresentedObject: A(currentCommit, commit)];
//			[menu addItem: item];
//		}		
		
		{
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle: @"Selective Undo" 
														   action: @selector(selectiveUndo:) 
													keyEquivalent: @""];
			[item setRepresentedObject: commit];
			[menu addItem: item];
		}

		{
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle: @"Selective Apply" 
														   action: @selector(selectiveApply:) 
													keyEquivalent: @""];
			[item setRepresentedObject: commit];
			[menu addItem: item];
		}

		[menu addItem: [NSMenuItem separatorItem]];
		
		{
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle: @"Switch To Commit" 
														   action: @selector(switchToCommit:) 
													keyEquivalent: @""];
			[item setRepresentedObject: commit];
			[menu addItem: item];
		}
		
		return menu;
	}
	return nil;
}

- (void)mouseUp: (NSEvent *)theEvent
{
    if ([theEvent clickCount] == 1)
	{
		NSPoint pt = [self convertPoint: [theEvent locationInWindow] 
							   fromView: nil];
		
		CORevisionID *commit = [graphRenderer commitAtPoint: pt];

        if (commit != nil)
        {
            NSLog(@"switch to %@", commit);
            
            // FIXME: Hacky to hit NSDocument directly from here!
            
            EWDocument *doc = [[NSDocumentController sharedDocumentController] currentDocument];
            
            [doc persistentSwitchToStateToken: commit];            
        }
	}
}

- (void)mouseEntered:(NSEvent *)theEvent
{    
    CORevisionID *commit = [theEvent userData];
    mouseoverCommit =  commit;
    [self setNeedsDisplay: YES];
    NSLog(@"show %@", commit);
    
    // FIXME: Hacky to hit NSDocument directly from here!
    
    EWDocument *doc = [[NSDocumentController sharedDocumentController] currentDocument];
    
    [doc loadStateToken: commit];
}

-(void)mouseExited:(NSEvent *)theEvent
{
    NSLog(@"restore current state");
    mouseoverCommit = nil;
    [self setNeedsDisplay: YES];
    
    
    // FIXME: Hacky to hit NSDocument directly from here!
    
    EWDocument *doc = [[NSDocumentController sharedDocumentController] currentDocument];
    
    [doc loadStateToken: [[[[doc currentPersistentRoot] editingBranch] currentRevision] revisionID]];
}

@end
