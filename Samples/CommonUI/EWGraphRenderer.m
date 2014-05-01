/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

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
	ETAssert(self.delegate != nil);

	trackNodesChronological =
		[NSArray arrayWithArray: [self.delegate allOrderedNodesToDisplayForTrack: track]];
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

/**
 * Returns -1 if all of the nodes are unassigned
 */
- (NSInteger) maxLevelFromUUIDInclusive: (ETUUID*)a toUUIDExclusive: (ETUUID*)b
{
	NSInteger max = -1;
	for (ETUUID *i = a; ![i isEqual: b]; i = [trackNodesChronological[[rowIndexForUUID[i] integerValue] + 1] UUID])
	{
		ETAssert(i != nil);
		NSNumber *level = levelForUUID[i];
		if (level != nil && [level integerValue] > max)
			max = [level integerValue];
	}
	return max;
}

- (NSInteger) assignLevelForUUID: (ETUUID *)currentRevision greaterThanSiblingLevel: (NSInteger)siblingLevel
{
	ETAssert([currentRevision isKindOfClass: [ETUUID class]]);
	
	// Have we already done this node?
	if (levelForUUID[currentRevision] != nil)
		return [levelForUUID[currentRevision] integerValue];

	// Is it a root?
	if ([[self parentUUIDsForRevisionUUID: currentRevision] count] == 0)
	{
		levelForUUID[currentRevision] = @(0);
	}
	else
	{
		NSArray *parentUUIDs = [self parentUUIDsForRevisionUUID: currentRevision];
		ETUUID *parentUUID = nil;
		
		// Set parentUUID to the first parent for which we have already assigned a level
		for (ETUUID *aParent in parentUUIDs)
		{
			if (levelForUUID[aParent] != nil)
			{
				parentUUID = aParent;
				break;
			}
		}
		
		ETAssert(parentUUID != nil);
		
		NSInteger value = [self maxLevelFromUUIDInclusive: currentRevision
										  toUUIDExclusive: parentUUID];
		
		NSNumber *parentLevel = levelForUUID[parentUUID];
		ETAssert(parentLevel != nil);
		
		if (value == -1)
		{
			const NSInteger level = MAX(siblingLevel + 1, [parentLevel integerValue]);
			levelForUUID[currentRevision] = @(level);
		}
		else
		{
			const NSInteger level = MAX(siblingLevel + 1, MAX(value + 1, [parentLevel integerValue]));
			levelForUUID[currentRevision] = @(level);
		}
	}
	
	NSArray *children = [self childrenForUUID: currentRevision];
	ETAssert(children != nil);
	
	NSInteger childLevel = -1;
	for (ETUUID *child in children)
	{
		childLevel = [self assignLevelForUUID: child greaterThanSiblingLevel: childLevel];
	}
	
	return [levelForUUID[currentRevision] integerValue];
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
	
	for (ETUUID *root in roots)
	{
		[self assignLevelForUUID: root greaterThanSiblingLevel: -1];
	}
}

- (void) addUUIDAndParents: (ETUUID *)aNode toSet: (NSMutableSet *)dest
{
	if ([dest containsObject: aNode])
		return;
	
	[dest addObject: aNode];
	
	for (ETUUID *parent in [self parentUUIDsForRevisionUUID: aNode])
	{
		[self addUUIDAndParents: parent toSet: dest];
	}
}

- (void) buildCurrentUUIDAndAncestors
{
	currentUUIDAndAncestors = [NSMutableSet new];
	
	if ([[track currentNode] UUID] != nil)
	{
		[self addUUIDAndParents: [[track currentNode] UUID] toSet: currentUUIDAndAncestors];
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

- (void) updateWithTrack: (id<COTrack>)aTrack
{
	track = aTrack;

	[self buildtrackNodesChronological];
	[self buildRowIndexForUUID];
	[self buildRevisionInfoForUUID];
	[self buildChildrenForUUID];
	[self buildLevelForUUID];
	[self buildGraphRows];
	[self buildCurrentUUIDAndAncestors];
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

- (NSRect) circleRectAtLevel: (NSInteger)level inRect: (NSRect)aRect
{
	aRect.size.width = aRect.size.height;
	aRect = NSInsetRect(aRect, 4, 4);
	
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

- (NSColor *)colorForUUID: (ETUUID *)commit
{
	return [self.delegate colorForNode: revisionInfoForUUID[commit]
		  isCurrentOrAncestorOfCurrent: [currentUUIDAndAncestors containsObject: commit]];
}

- (void) drawRevisionAtIndex: (NSUInteger)index inRect: (NSRect)aRect
{
	[NSGraphicsContext saveGraphicsState];
	
	[[NSBezierPath bezierPathWithRect: aRect] addClip];
	
	id <COTrackNode> revisionInfo = trackNodesChronological[index];
	ETUUID *commit = [revisionInfo UUID];
	const NSInteger level = [levelForUUID[commit] integerValue];


	// Draw lines
	
	EWGraphRow *graphRow = graphRows[index];
	
	for (ETUUID *parent in graphRow.intersectingLines)
	{
		for (ETUUID *child in [self childrenForUUID: parent])
		{
			[[self colorForUUID: child] setStroke];
			[self drawLineFromUUID: parent toUUID: child currentRow: index inRect: aRect];
		}
	}
	
	NSColor *commitColor = [self colorForUUID: commit];
	const BOOL isCurrentCommit = [[[track currentNode] UUID] isEqual: commit];
	const NSRect circleRect = [self circleRectAtLevel: level inRect: aRect];
	
	[commitColor setStroke];
	[[NSColor whiteColor] setFill];
	NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect: circleRect];
	[circle setLineWidth: isCurrentCommit ? 2 : 1];
	[circle fill];
	[circle stroke];
	
	if (isCurrentCommit)
	{
		NSBezierPath *outline = [NSBezierPath bezierPathWithOvalInRect: NSInsetRect(circleRect, -1, -1)];
		[outline setLineWidth: 1];
		[[NSColor blackColor] setStroke];
		[outline stroke];
	}
	
	[[commitColor colorWithAlphaComponent: 0.25] setFill];
	[circle fill];
	
	[NSGraphicsContext restoreGraphicsState];
}

@end
