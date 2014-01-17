#import "EWGraphRenderer.h"
#import <EtoileFoundation/Macros.h>
#import <CoreObject/CoreObject.h>
#import <CoreObject/CORevisionCache.h>

@implementation EWGraphRenderer

#if 0

- (NSArray *) commits
{
	return allCommitsSorted;
}

- (NSSize) size
{
	NSSize s = NSMakeSize(32 * [allCommitsSorted count], 32 * (maxLevelUsed + 1));
	
	return s;
}

- (NSRect) rectForCommit: (CORevision*)aCommit
{
	NSNumber *rowObj = [levelForUUID objectForKey: [aCommit UUID]];
	assert(rowObj != nil);
	NSUInteger row = [rowObj integerValue];
	NSUInteger col = [allCommitsSorted indexOfObject: aCommit];
	
	NSRect cellRect = NSMakeRect(col * 32, row * 32, 16, 16);
	
	return cellRect;
}

- (NSColor *)colorForCommit: (CORevision *)aCommit
{
    if ([aCommit isEqual: currentCommit_])
    {
        return [NSColor purpleColor];
    }
    else if ([branchCommits_ containsObject: aCommit])
    {
        return [[NSColor purpleColor] colorWithAlphaComponent: 0.66];
    }
    else
	{
		return [NSColor lightGrayColor];
	}
}

- (CGFloat) thicknessForCommit: (CORevision *)aCommit
{
    if ([aCommit isEqual: currentCommit_])
    {
        return 3.0;
    }
    else
	{
		return 1.0;
	}
}

- (void) drawWithHighlightedCommit: (CORevision *)aCommit
{
	for (NSUInteger col = 0; col < [allCommitsSorted count]; col++)
	{
		CORevision *commit = [allCommitsSorted objectAtIndex: col];
		
		NSColor *color = [self colorForCommit: commit];
		CGFloat thickness = [self thicknessForCommit: commit];
        
        if ([commit isEqual: aCommit])
        {
            color = [NSColor redColor];
        }
        
		NSRect r = [self rectForCommit: commit];
		NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect: r];
		
        [color set];
        [circle setLineWidth: thickness];
        [circle stroke];
    
		for (CORevision *child in [childrenForUUID objectForKey: [commit UUID]])
		{
			NSRect r2 = [self rectForCommit: child];
			
			NSPoint p = NSMakePoint(r.origin.x + r.size.width/2, r.origin.y + r.size.height/2);
			NSPoint p2 = NSMakePoint(r2.origin.x + r2.size.width/2, r2.origin.y + r2.size.height/2);
			
			p.x += 8;
			p2.x -= 8;
			
			[[self colorForCommit: child] set];
			EWDrawArrowFromTo(p, p2);
		}
	}
}

- (CORevision *)commitAtPoint: (NSPoint)aPoint
{
	for (CORevision *commit in allCommitsSorted)
	{
		if (NSPointInRect(aPoint, [self rectForCommit: commit]))
		{
			return commit;
		}
	}
	return nil;
}
#endif

#pragma mark - New code

static NSArray *RevisionInfosChronological(NSSet *commits)
{
    return [[commits allObjects] sortedArrayUsingComparator: ^(id obj1, id obj2) {
        CORevisionInfo *obj1Info = obj1;
        CORevisionInfo *obj2Info = obj2;
        
        return [[obj2Info date] compare: [obj1Info date]];
    }];
}

static NSSet *RevisionInfoSet(COPersistentRoot *proot)
{
	NSMutableSet *revisionInfos = [NSMutableSet new];
	for (COBranch *branch in proot.branches)
	{
		[revisionInfos addObjectsFromArray:
		 [proot.store revisionInfosForBranchUUID: branch.UUID
										 options: COBranchRevisionReadingParentBranches | COBranchRevisionReadingDivergentRevisions]];
	}
	return revisionInfos;
}

- (void) buildRevisionInfoForUUID
{
	ETAssert(revisionInfosChronological != nil);
	revisionInfoForUUID = [NSMutableDictionary new];
	for (CORevisionInfo *info in revisionInfosChronological)
	{
		revisionInfoForUUID[info.revisionUUID] = info;
	}
}

- (void) buildRevisionInfosChronological
{
	NSSet *revisionInfoSet = RevisionInfoSet(persistentRoot);
	revisionInfosChronological = RevisionInfosChronological(revisionInfoSet);
}

- (void) buildChildrenForUUID
{
	ETAssert(revisionInfosChronological != nil);
	childrenForUUID = [NSMutableDictionary dictionaryWithCapacity: [revisionInfosChronological count]];
	
	for (CORevisionInfo *aCommit in revisionInfosChronological)
	{
		childrenForUUID[aCommit.revisionUUID] = [NSMutableArray new];
	}
	for (CORevisionInfo *aCommit in revisionInfosChronological)
	{
		if (aCommit.parentRevisionUUID != nil)
		{
			[childrenForUUID[aCommit.parentRevisionUUID] addObject: aCommit.revisionUUID];
		}
		if (aCommit.mergeParentRevisionUUID != nil)
		{
			[childrenForUUID[aCommit.mergeParentRevisionUUID] addObject: aCommit.revisionUUID];
		}
	}
}

- (NSArray *) childrenForUUID: (ETUUID *)aUUID
{
	return childrenForUUID[aUUID];
}

- (NSArray *) graphRootUUIDS
{
	ETAssert(childrenForUUID != nil);
	
	NSMutableArray *roots = [NSMutableArray array];
	for (CORevisionInfo *aCommit in revisionInfosChronological)
	{
		if (nil == [self childrenForUUID: aCommit.parentRevisionUUID]
			&& nil == [self childrenForUUID: aCommit.mergeParentRevisionUUID])
		{
			[roots addObject: aCommit.revisionUUID];
		}
	}
	return roots;
}

- (NSInteger) maxLevelForDrawingGraphFromUUID: (ETUUID *)currentRevision
								 currentLevel: (NSInteger)currentLevel
{
	//NSLog(@"visiting %@", currentRevision);
	
	NSNumber *currentSavedLevel = levelForUUID[currentRevision];
	if (currentSavedLevel != nil)
	{
		//NSLog(@"%@ already has a level %@", currentRevision, currentSavedLevel);
		return currentLevel;
	}
	else
	{
		levelForUUID[currentRevision] = @(currentLevel);
	}
	
	NSArray *children = [self childrenForUUID: currentRevision];
	ETAssert(children != nil);
	
	NSInteger maxLevelUsed = currentLevel - 1;
	for (ETUUID *child in children)
	{
		maxLevelUsed = [self maxLevelForDrawingGraphFromUUID: child currentLevel: maxLevelUsed + 1];
	}
	return MAX(currentLevel, maxLevelUsed);
}

- (void) buildLevelForUUID
{
	NSArray *roots = [self graphRootUUIDS];
	
	// now to find the Y position, we do a DFS on the display graph.
	// the first root gets assigned level 0. when we visit a node,
	// the first child gets assigned to the current level, the second
	// child gets the current level + 1, etc. then we just visit the children
	// in order.
	//
	
	// FIXME: we need to do some extra work to handle the case when
	// a DAG in the forest has more than one root. this should be rare in practice,
	// because it means you merged two projects that started from scratch with no common
	// ancestor. but we should still support drawing graphs with that.
	
	levelForUUID =  [NSMutableDictionary dictionary];
	
	NSInteger maxLevel = 0;
	for (ETUUID *root in roots)
	{
		//NSLog(@"Starting root %@ at %d", root, (int)maxLevel);
		maxLevel = [self maxLevelForDrawingGraphFromUUID: root currentLevel: maxLevel] + 1;
	}
}

- (void) updateWithProot: (COPersistentRoot *)aproot
{
	persistentRoot = aproot;

	[self buildRevisionInfosChronological];
	[self buildRevisionInfoForUUID];
	[self buildChildrenForUUID];
	[self buildLevelForUUID];
}

- (NSUInteger) count
{
	return [revisionInfosChronological count];
}

- (CORevision *) revisionAtIndex: (NSUInteger)index
{
	CORevisionInfo *info = revisionInfosChronological[index];
	return [CORevisionCache revisionForRevisionUUID: info.revisionUUID
								 persistentRootUUID: persistentRoot.UUID
										  storeUUID: persistentRoot.store.UUID];
}

#pragma mark - Drawing

static void EWDrawHorizontalArrowOfLength(CGFloat length)
{
	const CGFloat cap = 8;
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint: NSMakePoint(0, 0)];
	[path lineToPoint: NSMakePoint(length - cap, 0)];
	[path stroke];
	
	[path removeAllPoints];
	[path moveToPoint: NSMakePoint(length - cap, cap / 2.0)];
	[path lineToPoint: NSMakePoint(length - cap, cap / -2.0)];
	[path lineToPoint: NSMakePoint(length, 0)];
	[path closePath];
	[path fill];
}

#define EWRandFloat() (rand()/(CGFloat)(RAND_MAX))

static void EWDrawArrowFromTo(NSPoint p1, NSPoint p2)
{
	[NSGraphicsContext saveGraphicsState];
	
	NSAffineTransform *xform = [NSAffineTransform transform];
	[xform translateXBy:p1.x yBy:p1.y];
	[xform rotateByRadians: atan2(p2.y-p1.y, p2.x-p1.x)];
	[xform concat];
	
	EWDrawHorizontalArrowOfLength(sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2)));
	
	[NSGraphicsContext restoreGraphicsState];
}

- (NSRect) circleRectAtLevel: (NSInteger)level inRect: (NSRect)aRect
{
	aRect.size.width = aRect.size.height;
	aRect = NSInsetRect(aRect, 3, 3);
	
	aRect.origin.x += level * (2.5 * aRect.size.width);
	return aRect;
}

- (NSRect) rectForUUID: (ETUUID *)commit currentRow: (NSUInteger)row inRect: (NSRect)aRect
{
	const NSInteger level = [levelForUUID[commit] integerValue];
	const NSInteger rowToDraw = [revisionInfosChronological indexOfObject: revisionInfoForUUID[commit]];
	
	NSRect currentRowRect = [self circleRectAtLevel: level inRect: aRect];
	
	currentRowRect.origin.y += ((NSInteger)rowToDraw - row) * aRect.size.height;
	
	return currentRowRect;
}

- (void) drawLineFromUUID: (ETUUID *)commit1 toUUID: (ETUUID *)commit2 currentRow: (NSUInteger)row inRect: (NSRect)aRect
{
	NSRect r = [self rectForUUID: commit1 currentRow: row inRect: aRect];
	NSRect r2 = [self rectForUUID: commit2 currentRow: row inRect: aRect];
	
	NSPoint p = NSMakePoint(r.origin.x + r.size.width/2, r.origin.y + r.size.height/2);
	NSPoint p2 = NSMakePoint(r2.origin.x + r2.size.width/2, r2.origin.y + r2.size.height/2);
	
	EWDrawArrowFromTo(p, p2);
	
//	NSBezierPath *bp = [NSBezierPath bezierPath];
//	[bp moveToPoint: p];
//	[bp lineToPoint: p2];
//	[bp stroke];
}

- (void) drawLinesRecursive: (ETUUID *)commit currentRow: (NSUInteger)row inRect: (NSRect)aRect
{
	for (ETUUID *child in [self childrenForUUID: commit])
	{
		[self drawLineFromUUID: commit toUUID: child currentRow: row inRect: aRect];
	}
	
	// Draw the lines for parents until we hit level 0;
	CORevisionInfo *revisionInfo = revisionInfoForUUID[commit];
	
	if (revisionInfo.parentRevisionUUID != nil)
	{
		[self drawLinesRecursive: revisionInfo.parentRevisionUUID currentRow: row inRect: aRect];
	}
	
	if (revisionInfo.mergeParentRevisionUUID != nil)
	{
		[self drawLinesRecursive: revisionInfo.mergeParentRevisionUUID currentRow: row inRect: aRect];
	}
}

- (void) drawRevisionAtIndex: (NSUInteger)index inRect: (NSRect)aRect
{
	CORevisionInfo *revisionInfo = revisionInfosChronological[index];
	ETUUID *commit = [revisionInfo revisionUUID];
	const NSInteger level = [levelForUUID[commit] integerValue];

	[[NSColor blueColor] set];
	
	NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect: [self circleRectAtLevel: level inRect: aRect]];
	[circle setLineWidth: 1];
	[circle stroke];
	
	[self drawLinesRecursive: commit currentRow: index inRect: aRect];
}

@end
