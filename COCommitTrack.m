#import "COCommitTrack.h"
#import "COEditingContext.h"
#import "COStore.h"
#import "COObject.h"
#import "CORevision.h"
#import "FMDatabase.h"

#import <Foundation/NSException.h>

#define CACHE_AMOUNT 5

@implementation COCommitTrack

@synthesize trackedObject;

- (id)initWithTrackedObjects: (NSSet *)trackedObjects
{
	self = [super initWithTrackedObjects: trackedObjects];
	if (self == nil)
		return nil;

	COObject *object = [trackedObjects anyObject];
	COEditingContext *ctx = [object editingContext];
	COStore *store = [ctx store];
	if (nil == store)
	{
		[self release];
		[NSException raise: NSInvalidArgumentException
		            format: @"Cannot load commit _track for object %@ which does not have an editing context", object];
	}
	ASSIGN(trackedObject, object);
	_cachedNodes =  [[NSMutableArray alloc] initWithCapacity: CACHE_AMOUNT]; 
	_currentNode = NSNotFound;
	if ([trackedObject revision] == nil)
	{
		return self;
	}
	[self cacheNodesForward: CACHE_AMOUNT backward: CACHE_AMOUNT];

	return self;	
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [COCommitTrack class]])
	{
		return [trackedObject isEqual: [rhs trackedObject]]
			&& [[trackedObject editingContext] isEqual: [[rhs trackedObject] editingContext]];
	}
	return [super isEqual: rhs];
}
- (void)dealloc
{
	DESTROY(trackedObject);
	[_cachedNodes release];
	[super dealloc];
}
- (COTrackNode*)currentNode
{
	if (_currentNode != NSNotFound)
		return [_cachedNodes objectAtIndex: _currentNode];
	else
		return nil;
}
- (void)undo
{
	if ([self currentNode] == nil)
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot undo object %@ which does not have any commits", trackedObject];
	COStore *store = [[trackedObject editingContext] store];
	CORevision *currentRevision = [store undoOnCommitTrack: [trackedObject UUID]];
	if (_currentNode == 0)
		[self cacheNodesForward: 0 backward: CACHE_AMOUNT];
	_currentNode--;
	NSAssert(_currentNode != NSNotFound &&
			![[NSNull null] isEqual: [_cachedNodes objectAtIndex: _currentNode]],
			@"Record undone to is cached");
	// TODO: Reset object state to old object.
	[[trackedObject editingContext] 
		reloadRootObjectTree: trackedObject
		          atRevision: currentRevision];
}
- (void)redo
{
	if ([self currentNode] == nil)
		[NSException raise: NSInternalInconsistencyException
		            format: @"Cannot redo object %@ which does not have any commits", trackedObject];
	COStore *store = [[trackedObject editingContext] store];
	CORevision *currentRevision = [store redoOnCommitTrack: [trackedObject UUID]];
	if ([_cachedNodes count] == (_currentNode+1))
		[self cacheNodesForward: CACHE_AMOUNT backward: 0];
	_currentNode++;
	// Check to make sure new node was cached
	NSAssert([_cachedNodes count] > _currentNode && 
			![[NSNull null] isEqual: [_cachedNodes objectAtIndex: _currentNode]],
			@"Record redone to is cached");
	// TODO: Reset object state to old object.
	[[trackedObject editingContext] 
		reloadRootObjectTree: trackedObject
		          atRevision: currentRevision];
}

- (void)newCommitAtRevision: (CORevision*)revision
{
	// COStore takes care of updating the database, so we 
	// just use this as a notification to update our cache.
	COTrackNode *newNode = [COTrackNode
		nodeWithRevision: revision
		         onTrack: self];
	if (_currentNode != NSNotFound)
		_currentNode++;
	else
		_currentNode = 0;
	[_cachedNodes insertObject: newNode
	                  atIndex: _currentNode];
	NSUInteger lastIndex = [_cachedNodes count] - 1;
	if (lastIndex > _currentNode)
		[_cachedNodes removeObjectsInRange: NSMakeRange(_currentNode + 1, lastIndex - _currentNode)];
}

- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward
{
	COStore *store = [[trackedObject editingContext] store];
	NSArray* revisions = 
		[store loadCommitTrackForObject: [trackedObject UUID]
		                   fromRevision: [[self currentNode] revision] 
		                    nodesForward: forward
		                   nodesBackward: backward];
	NSArray *backwardRange = [revisions subarrayWithRange: NSMakeRange(0, backward)];
	NSArray *forwardRange = [revisions subarrayWithRange: NSMakeRange(backward+1, forward)];

	NSUInteger insertPoint;
	if (_currentNode == NSNotFound)
		insertPoint = _currentNode = 0;
	else
		insertPoint = _currentNode;
	NSEnumerator *backwardRangeEnum = [backwardRange reverseObjectEnumerator];
	for(CORevision *revision = [backwardRangeEnum nextObject]; revision != nil; revision = [backwardRangeEnum nextObject])
	{
		if ([[NSNull null] isEqual: revision])
			break;
		COTrackNode *node = [COTrackNode
			nodeWithRevision: revision
			         onTrack: self];
		if (insertPoint == 0)
		{
			[_cachedNodes insertObject: node atIndex: 0];
			++ _currentNode;
		}
		else
		{
			[_cachedNodes replaceObjectAtIndex: insertPoint withObject: node];
			-- insertPoint;
		}
	}

	CORevision *currentNodeRevision = [revisions objectAtIndex: backward];
	if ([[NSNull null] isEqual: currentNodeRevision])
	{
		_currentNode = NSNotFound;
		return;
	}

	COTrackNode *currentNode = [COTrackNode
		nodeWithRevision: [revisions objectAtIndex: backward]
			 onTrack: self];

	if (_currentNode >= [_cachedNodes count])
	{
		[_cachedNodes addObject: currentNode];
	}
	else
		[_cachedNodes replaceObjectAtIndex: _currentNode withObject: currentNode];

	insertPoint = _currentNode + 1;
	FOREACH (forwardRange, revision, CORevision*)
	{
		if ([[NSNull null] isEqual: revision])
			break;
		COTrackNode *node = [COTrackNode
			nodeWithRevision: revision
			         onTrack: self];
		if (insertPoint >= [_cachedNodes count])
		{
			[_cachedNodes addObject: node];
		}
		else
		{
			[_cachedNodes replaceObjectAtIndex: insertPoint withObject: node];
		}
		++ insertPoint;
	}
}

@end
