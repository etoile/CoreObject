#import "EWGraphRenderer.h"
#import <EtoileFoundation/Macros.h>
#import <CoreObject/CoreObject.h>
#import <CoreObject/CORevisionCache.h>

@interface EWGraphRow : NSObject
@property (nonatomic) NSMutableArray *intersectingLines;
@property (nonatomic) ETUUID *revisionUUID;
@end

@implementation EWGraphRow
@synthesize intersectingLines, revisionUUID;
@end


@implementation EWGraphRenderer

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
	NSSet *revisionInfos = [NSSet setWithArray:
							[proot.store revisionInfosForBackingStoreOfPersistentRootUUID: proot.UUID]];
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

- (void) buildRowIndexForUUID
{
	ETAssert(revisionInfosChronological != nil);
	
	rowIndexForUUID = [NSMutableDictionary new];
	NSUInteger i = 0;
	for (CORevisionInfo *info in revisionInfosChronological)
	{
		rowIndexForUUID[info.revisionUUID] = @(i);
		i++;
	}
}

/**
 * Returns an array with the 0, 1, or 2 parent UUIDs of the given revision UUID
 */
- (NSArray *)parentUUIDsForRevisionUUID: (ETUUID *)aUUID
{
	NSMutableArray *result = [NSMutableArray new];
	CORevisionInfo *aCommit = revisionInfoForUUID[aUUID];
	ETAssert(aCommit != nil);
	
	if (aCommit.parentRevisionUUID != nil)
	{
		[result addObject: aCommit.parentRevisionUUID];
	}
	if (aCommit.mergeParentRevisionUUID != nil)
	{
		[result addObject: aCommit.mergeParentRevisionUUID];
	}
	return result;
}

- (NSArray *) childrenForUUID: (ETUUID *)aUUID
{
	return childrenForUUID[aUUID];
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
		for (ETUUID *parentUUID in [self parentUUIDsForRevisionUUID: aCommit.revisionUUID])
		{
			[childrenForUUID[parentUUID] addObject: aCommit.revisionUUID];
		}
	}
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
	ETAssert(revisionInfosChronological != nil);
	
	graphRows = [NSMutableArray new];
	for (CORevisionInfo *aCommit in revisionInfosChronological)
	{
		EWGraphRow *row = [EWGraphRow new];
		row.revisionUUID = aCommit.revisionUUID;
		row.intersectingLines = [NSMutableArray new];
		[graphRows addObject: row];
	}
	
	for (CORevisionInfo *aCommit in revisionInfosChronological)
	{
		for (ETUUID *parentUUID in [self parentUUIDsForRevisionUUID: aCommit.revisionUUID])
		{
			NSNumber *childIndexObject = rowIndexForUUID[aCommit.revisionUUID];
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

- (void) updateWithProot: (COPersistentRoot *)aproot
{
	persistentRoot = aproot;

	[self buildRevisionInfosChronological];
	[self buildRowIndexForUUID];
	[self buildRevisionInfoForUUID];
	[self buildChildrenForUUID];
	[self buildLevelForUUID];
	[self buildGraphRows];
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
	NSNumber *levelObject = levelForUUID[commit];
	ETAssert(levelObject != nil);
	const NSInteger level = [levelObject integerValue];
	
	const NSUInteger rowToDraw = [revisionInfosChronological indexOfObject: revisionInfoForUUID[commit]];
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
	
	NSLog(@"%@ to %@ %@ to %@", commit1, commit2, NSStringFromPoint(p), NSStringFromPoint(p2));
	
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
	
	CORevisionInfo *revisionInfo = revisionInfosChronological[index];
	ETUUID *commit = [revisionInfo revisionUUID];
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
	[circle setLineWidth: [[[persistentRoot currentRevision] UUID] isEqual: commit] ? 2 : 1];
	[circle fill];
	[circle stroke];
	
	[NSGraphicsContext restoreGraphicsState];
}

@end
