#import <Foundation/NSObject.h>
#import <ObjectMerging/COTrack.h>

@class NSMutableArray;
@class COObject, CORevision;

/**
  * A persistent history track on an object. Unlike COHistoryTrack,
  * this class persists the track and moves a pointer for redo/undo
  */
@interface COCommitTrack : COTrack
{
	COObject *_commitLog;
	NSInteger _currentNode;
	NSMutableArray *_cachedNodes;
}

- (COTrackNode*)currentNode;
- (COObject*)trackedObject;
- (void)undo;
- (void)redo;
@end

@interface COCommitTrack (PrivateToCoreObject)
- (void)newCommitAtRevision: (CORevision*)revision;
- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward;
@end
