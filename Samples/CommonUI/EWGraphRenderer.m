#import "EWGraphRenderer.h"
#import <EtoileFoundation/Macros.h>
#import <CoreObject/CoreObject.h>
#import <CoreObject/COEditingContext+Private.h>
#import <CoreObject/COCommandGroup.h>

@interface EWGraphRow : NSObject
@property (nonatomic) NSMutableArray *intersectingLines;
@property (nonatomic) ETUUID *revisionUUID;
@end

@implementation EWGraphRow
@synthesize intersectingLines, revisionUUID;
@end


@implementation EWGraphRenderer

static NSArray *sortTrackNodes(NSArray *commits)
{
    return [commits sortedArrayUsingComparator: ^(id obj1, id obj2) {
//        COCommandGroup *obj1Info = obj1;
//        COCommandGroup *obj2Info = obj2;
//        
//        if (obj2Info.sequenceNumber < obj1Info.sequenceNumber)
//		return NSOrderedAscending;
//		else if (obj2Info.sequenceNumber > obj1Info.sequenceNumber)
//		return NSOrderedDescending;
//		else
//		return NSOrderedSame;

        id<COTrackNode> obj1Node = obj1;
        id<COTrackNode> obj2Node = obj2;
		return [[obj2Node date] compare: [obj1Node date]];
	}];
}

- (void) buildRevisionInfoForUUID
{
	ETAssert(trackNodesChronological != nil);
	revisionInfoForUUID = [NSMutableDictionary new];
	for (id<COTrackNode> info in trackNodesChronological)
	{
		revisionInfoForUUID[info.UUID] = info;
	}
}

- (void) buildtrackNodesChronological
{
	NSArray *allCommands = [(COUndoTrack *)track allCommands];
	trackNodesChronological = sortTrackNodes(allCommands);
}

- (void) buildRowIndexForUUID
{
	ETAssert(trackNodesChronological != nil);
	
	rowIndexForUUID = [NSMutableDictionary new];
	NSUInteger i = 0;
	for (id<COTrackNode> info in trackNodesChronological)
	{
		rowIndexForUUID[info.UUID] = @(i);
		i++;
	}
}

/**
 * Returns an array with the 0, 1, or 2 parent UUIDs of the given revision UUID
 */
- (NSArray *)parentUUIDsForRevisionUUID: (ETUUID *)aUUID
{
	id<COTrackNode> aCommit = revisionInfoForUUID[aUUID];
	ETAssert(aCommit != nil);
	
	NSMutableArray *result = [NSMutableArray new];
	if ([aCommit parentNode] != nil)
	{
		[result addObject: [[aCommit parentNode] UUID]];
	}
	if ([aCommit mergeParentNode] != nil)
	{
		[result addObject: [[aCommit mergeParentNode] UUID]];
	}
	return result;
}

- (NSArray *) childrenForUUID: (ETUUID *)aUUID
{
	return childrenForUUID[aUUID];
}

- (void) buildChildrenForUUID
{
	ETAssert(trackNodesChronological != nil);
	childrenForUUID = [NSMutableDictionary dictionaryWithCapacity: [trackNodesChronological count]];
	
	for (id<COTrackNode> aCommit in trackNodesChronological)
	{
		childrenForUUID[aCommit.UUID] = [NSMutableArray new];
	}
	for (id<COTrackNode> aCommit in trackNodesChronological)
	{
		for (ETUUID *parentUUID in [self parentUUIDsForRevisionUUID: aCommit.UUID])
		{
			[childrenForUUID[parentUUID] addObject: aCommit.UUID];
		}
	}
}


- (NSArray *) graphRootUUIDS
{
	ETAssert(childrenForUUID != nil);
	
	NSMutableArray *roots = [NSMutableArray array];
	for (id<COTrackNode> aCommit in trackNodesChronological)
	{
		if (nil == [self childrenForUUID: [[aCommit parentNode] UUID]])
		{
			[roots addObject: aCommit.UUID];
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

	levelForUUID =  [NSMutableDictionary dictionary];
	
	NSInteger maxLevel = 0;
	for (ETUUID *root in roots)
	{
		//NSLog(@"Starting root %@ at %d", root, (int)maxLevel);
		maxLevel = [self maxLevelForDrawingGraphFromUUID: root currentLevel: maxLevel] + 1;
	}
}

- (void) buildGraphRows
{
	ETAssert(trackNodesChronological != nil);
	
	graphRows = [NSMutableArray new];
	for (id<COTrackNode> aCommit in trackNodesChronological)
	{
		EWGraphRow *row = [EWGraphRow new];
		row.revisionUUID = aCommit.UUID;
		row.intersectingLines = [NSMutableArray new];
		[graphRows addObject: row];
	}
	
	for (id<COTrackNode> aCommit in trackNodesChronological)
	{
		for (ETUUID *parentUUID in [self parentUUIDsForRevisionUUID: aCommit.UUID])
		{
			NSNumber *childIndexObject = rowIndexForUUID[aCommit.UUID];
			NSNumber *parentIndexObject = rowIndexForUUID[parentUUID];
			ETAssert(childIndexObject != nil);
			ETAssert(parentIndexObject != nil);
			
			const NSUInteger childIndex = [childIndexObject unsignedIntegerValue];
			const NSUInteger parentIndex = [parentIndexObject unsignedIntegerValue];
			ETAssert(childIndex < parentIndex);
			
			for (NSUInteger i = childIndex; i <= parentIndex; i++)
			{
				EWGraphRow *currentRow = graphRows[i];
				[currentRow.intersectingLines addObject: parentUUID];
			}
		}
	}
}

//- (void) buildBranchForRevisionUUID
//{
//	branchHeadForRevisionUUID = [NSMutableDictionary new];
//	branchCurrentForRevisionUUID = [NSMutableDictionary new];
//	
//	for (COBranch *branch in track.branches)
//	{
//		if (branch.headRevision != nil)
//			branchHeadForRevisionUUID[branch.headRevision.UUID] = branch;
//		if (branch.currentRevision != nil)
//			branchCurrentForRevisionUUID[branch.currentRevision.UUID] = branch;
//	}
//}

- (void) updateWithTrack: (id<COTrack>)aTrack
{
	track = aTrack;

	[self buildtrackNodesChronological];
	[self buildRowIndexForUUID];
	[self buildRevisionInfoForUUID];
	[self buildChildrenForUUID];
	[self buildLevelForUUID];
	[self buildGraphRows];
//	[self buildBranchForRevisionUUID];
}

- (NSUInteger) count
{
	return [trackNodesChronological count];
}

- (id<COTrackNode>) revisionAtIndex: (NSUInteger)index
{
	ETAssert(index != NSNotFound);
	id<COTrackNode> info = trackNodesChronological[index];
	return info;
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
	NSNumber *levelObject = levelForUUID[commit];
	ETAssert(levelObject != nil);
	const NSInteger level = [levelObject integerValue];
	
	const NSUInteger rowToDraw = [trackNodesChronological indexOfObject: revisionInfoForUUID[commit]];
	ETAssert(rowToDraw != NSNotFound);
	
	// We are in flipped coordinates
	
	NSRect currentRowRect = [self circleRectAtLevel: level inRect: aRect];
	
	currentRowRect.origin.y += ((CGFloat)rowToDraw - (CGFloat)row) * aRect.size.height;
	
	return currentRowRect;
}

- (void) drawLineFromUUID: (ETUUID *)commit1 toUUID: (ETUUID *)commit2 currentRow: (NSUInteger)row inRect: (NSRect)aRect
{
	NSRect r = [self rectForUUID: commit1 currentRow: row inRect: aRect];
	NSRect r2 = [self rectForUUID: commit2 currentRow: row inRect: aRect];
	
	NSPoint p = NSMakePoint(r.origin.x + r.size.width/2, r.origin.y + r.size.height/2);
	NSPoint p2 = NSMakePoint(r2.origin.x + r2.size.width/2, r2.origin.y + r2.size.height/2);
	
	//NSLog(@"%@ to %@ %@ to %@", commit1, commit2, NSStringFromPoint(p), NSStringFromPoint(p2));
	
//	EWDrawArrowFromTo(p, p2);
	
	NSBezierPath *bp = [NSBezierPath bezierPath];
	[bp moveToPoint: p];
	[bp lineToPoint: p2];
	[bp stroke];
}

- (void) drawRevisionAtIndex: (NSUInteger)index inRect: (NSRect)aRect
{
	[NSGraphicsContext saveGraphicsState];
	
	[[NSBezierPath bezierPathWithRect: aRect] setClip];
	
	id <COTrackNode> revisionInfo = trackNodesChronological[index];
	ETUUID *commit = [revisionInfo UUID];
	const NSInteger level = [levelForUUID[commit] integerValue];

	
	[[NSColor blueColor] set];

	// Draw lines
	
	EWGraphRow *graphRow = graphRows[index];
	
	for (ETUUID *parent in graphRow.intersectingLines)
	{
		for (ETUUID *child in [self childrenForUUID: parent])
		{
			[self drawLineFromUUID: parent toUUID: child currentRow: index inRect: aRect];
		}
	}
	
	[[NSColor blueColor] setStroke];
	[[NSColor whiteColor] setFill];
	NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect: [self circleRectAtLevel: level inRect: aRect]];
	[circle setLineWidth: [[[track currentNode] UUID] isEqual: commit] ? 2 : 1];
	[circle fill];
	[circle stroke];
	
	[NSGraphicsContext restoreGraphicsState];
}

//- (NSArray *) branchesForIndex: (NSUInteger) index
//{
//	NSMutableArray *result = [NSMutableArray new];
//	ETUUID *revUUID = [[self revisionAtIndex: index] UUID];
//	
//	if (revUUID != nil)
//	{
//		if (branchHeadForRevisionUUID[revUUID] != nil)
//			[result addObject: branchHeadForRevisionUUID[revUUID]];
//		if (branchCurrentForRevisionUUID[revUUID] != nil)
//			[result addObject: branchCurrentForRevisionUUID[revUUID]];
//	}
//	return result;
//}

@end
