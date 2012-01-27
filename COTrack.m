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

- (id)initWithTrackedObjects: (NSSet *)objects
{
	SUPERINIT;
	cachedNodes =  [[NSMutableArray alloc] init]; 
	currentNodeIndex = NSNotFound;
	return self;	
}

- (NSSet *)trackedObjects
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

- (COTrackNode *)nextNodeOnTrackFrom: (COTrackNode *)aNode backwards: (BOOL)back
{
	return nil;
}

- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (void)undo
{

}

- (void)redo
{

}

- (void)undoNode: (COTrackNode *)aNode
{

}

- (BOOL)canUndo
{
	return ([[self currentNode] previousNode] != nil);
}

- (BOOL)canRedo
{
	return ([[self currentNode] nextNode] != nil);
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
		return ([revision isEqual: [rhs revision]] && [track isEqual: [rhs track]]);
	}
	return NO;
}

// NOTE: For Mac OS X at least, KVC doesn't check -forwardingTargetForSelector:, 
// so implementing it is pretty much useless. We had to reimplement the accessors (see below).
- (id)forwardingTargetForSelector: (SEL)aSelector
{
	if ([revision respondsToSelector: aSelector])
	{
		return revision;
	}
	return nil;
}

- (CORevision *)revision
{
	return revision;
}

- (COTrack *)track
{
	return track;
}

- (COTrackNode *)previousNode
{
	return [track nextNodeOnTrackFrom: self backwards: YES];
}

- (COTrackNode *)nextNode
{
	return [track nextNodeOnTrackFrom: self backwards: NO];
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

- (ETUUID *)objectUUID
{
	return [revision objectUUID];
}

- (NSDate *)date
{
	return [revision date];
}

- (NSString *)type
{
	return [revision type];
}

- (NSString *)shortDescription;
{
	return [revision shortDescription];
}

- (NSString *)longDescription
{
	return [revision longDescription];
}

- (NSArray *)changedObjectUUIDs
{
	return [revision changedObjectUUIDs];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: [revision propertyNames]];
}

@end
