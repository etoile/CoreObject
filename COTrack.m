/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COTrack.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COTrack

+ (void) initialize
{
	if (self != [COTrack class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
}

+ (id)trackWithObject: (COObject *)anObject
{
	return AUTORELEASE([[self alloc] initWithTrackedObjects: S(anObject)]);
}

- (id)initWithTrackedObjects: (NSSet *)trackedObjects
{
	SUPERINIT;
	cachedNodes =  [[NSMutableArray alloc] init]; 
	currentNodeIndex = NSNotFound;
	return self;	
}

- (NSSet *)objects
{
	return [NSSet set];
}

- (COTrackNode *)currentNode
{
	return (currentNodeIndex != NSNotFound ? [cachedNodes objectAtIndex: currentNodeIndex] : nil);
}

- (void)setCurrentNode: (COTrackNode *)node
{

}

- (NSMutableArray *)cachedNodes
{
	return cachedNodes;
}

- (void)undo
{

}

- (void)redo
{

}

/** Returns YES. */
- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return 	[self cachedNodes];
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: [self cachedNodes]];
}

@end


@implementation COTrackNode

+ (id)nodeWithRevision: (CORevision *)aRevision onTrack: (COTrack *)aTrack;
{
	return AUTORELEASE([[self alloc] initWithRevision: aRevision onTrack: aTrack]);
}

- (id)initWithRevision: (CORevision *)rev onTrack: (COTrack *)aTrack
{
	SUPERINIT;
	ASSIGN(revision, rev);
	track = aTrack;
	return self;
}

- (void)dealloc
{
	[revision release];
	[super dealloc];
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [COTrackNode class]])
	{
		return ([revision isEqual: [rhs revision]] && 
			[track isEqual: [rhs track]]);
	}
	return [super isEqual: rhs];
}

- (CORevision *)revision
{
	return revision;
}

- (COTrack *)track
{
	return track;
}

- (NSDictionary *)metadata
{
	return [revision metadata];
}

- (uint64_t)revisionNumber
{
	return [revision revisionNumber];
}

- (ETUUID *)UUID
{
	return [revision UUID];
}

- (NSArray *)changedObjectUUIDs
{
	return [revision changedObjectUUIDs];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"revisionNumber", @"UUID", @"metadata", @"changedObjectUUIDs")];
}

@end
