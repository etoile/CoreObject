#import <Foundation/NSObject.h>

@class NSMutableArray;
@class COCommitTrackNode;
@class COObject;
@class CORevision;

/**
  * A persistent history track on an object. Unlike COHistoryTrack,
  * this class persists the track and moves a pointer for redo/undo
  */
@interface COCommitTrack : NSObject
{
	COObject *_commitLog;
	NSInteger _currentNode;
	NSMutableArray *_cachedNodes;
}

+ (COCommitTrack*)commitTrackForObject: (COObject*)object;
- (COCommitTrackNode*)currentNode;
- (COObject*)trackedObject;
- (void)undo;
- (void)redo;
@end

@interface COCommitTrack (PrivateToCoreObject)
- (void)newCommitAtRevision: (CORevision*)revision;
- (void)cacheNodesForward: (NSUInteger)forward backward: (NSUInteger)backward;
@end

@interface COCommitTrackNode : NSObject
{
	COCommitTrack *_track;
	CORevision *_revision;
}
+ (COCommitTrackNode*)nodeWithRevision: (CORevision*)revision onTrack: (COCommitTrack*)track;
- (CORevision*)revision;
- (COCommitTrack*)commitTrack;
@end
