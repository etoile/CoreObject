#import "EWHistoryGraphView.h"
#import "EWGraphRenderer.h"
#import <EtoileFoundation/Macros.h>

#import "EWDocument.h"

@implementation EWHistoryGraphView

- (id) initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {        
    }
    
    return self;
}

- (void)dealloc
{
    [trackingRects release];
    [super dealloc];
}
 
- (void) setPersistentRoot: (COPersistentRootInfo *)proot
                    branch: (COBranch*)aBranch
                     store: (COSQLiteStore*)aStore
{
    NSMutableArray *allCommitsOnAllBranches = [NSMutableArray array];

    for (COBranch *branch in [proot branches])
    {
        [allCommitsOnAllBranches addObjectsFromArray: [branch allCommits]];
    }
    
    [self setGraphRenderer: [[[EWGraphRenderer alloc] initWithCommits: allCommitsOnAllBranches
                                                        branchCommits: [aBranch allCommits]
                                                        currentCommit: [aBranch currentRevisionID]
                                                                store: aStore] autorelease]];
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
	COSQLiteStore *store = [graphRenderer store];
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
	ASSIGN(graphRenderer, aRenderer);
	
	//NSLog(@"Graph renderer size: %@", NSStringFromSize([graphRenderer size]));
	
	[self setFrameSize: [graphRenderer size]];
	[self setNeedsDisplay: YES];
}

-(void)resetCursorRects
{
    [super resetCursorRects];
    
	// Update tooltips
	
	[self removeAllToolTips];
    if (trackingRects != nil)
    {
        for (NSNumber *number in trackingRects)
        {
            [self removeTrackingRect: [number integerValue]];
        }
    }
    ASSIGN(trackingRects, [NSMutableArray array]);
    
	for (CORevisionID *commit in [graphRenderer commits])
	{
		NSRect r = [graphRenderer rectForCommit: commit];
		[self addToolTipRect:r owner:self userData:commit];
        
        NSInteger tag = [self addTrackingRect:r owner:self userData:commit assumeInside:NO];
        [trackingRects addObject: [NSNumber numberWithInteger: tag]];
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
		NSMenu *menu = [[[NSMenu alloc] initWithTitle: @""] autorelease];

//		{
//			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle: @"Diff with Current Commit" 
//														   action: @selector(diffCommits:) 
//													keyEquivalent: @""] autorelease];
//			[item setRepresentedObject: A(currentCommit, commit)];
//			[menu addItem: item];
//		}		
		
		{
			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle: @"Selective Undo" 
														   action: @selector(selectiveUndo:) 
													keyEquivalent: @""] autorelease];
			[item setRepresentedObject: commit];
			[menu addItem: item];
		}

		{
			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle: @"Selective Apply" 
														   action: @selector(selectiveApply:) 
													keyEquivalent: @""] autorelease];
			[item setRepresentedObject: commit];
			[menu addItem: item];
		}

		[menu addItem: [NSMenuItem separatorItem]];
		
		{
			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle: @"Switch To Commit" 
														   action: @selector(switchToCommit:) 
													keyEquivalent: @""] autorelease];
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
    ASSIGN(mouseoverCommit, commit);
    [self setNeedsDisplay: YES];
    NSLog(@"show %@", commit);
    
    // FIXME: Hacky to hit NSDocument directly from here!
    
    EWDocument *doc = [[NSDocumentController sharedDocumentController] currentDocument];
    
    [doc loadStateToken: commit];
}

-(void)mouseExited:(NSEvent *)theEvent
{
    NSLog(@"restore current state");
    DESTROY(mouseoverCommit);
    [self setNeedsDisplay: YES];
    
    
    // FIXME: Hacky to hit NSDocument directly from here!
    
    EWDocument *doc = [[NSDocumentController sharedDocumentController] currentDocument];
    
    [doc loadStateToken: [[[doc currentPersistentRoot] currentBranch] currentRevisionID]];
}

@end
