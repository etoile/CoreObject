#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class CORevision, COObject, COStore;
@class COHistoryTrackNode;

/**
 * A history track is a view on the database of commits, presenting
 * them as a history graph. It is not persistent or cached in any way.
 *
 * It also allow exposes a simlpe NSUndoManager-like way of navigating
 * history.
 *
 * Undo/redo causes a new commit.
 * Similar idea as http://www.loria.fr/~weiss/pmwiki/uploads/Main/CollaborateCom.pdf
 */
@interface COHistoryTrack : NSObject <ETCollection>
{
	COObject *trackObject;
	BOOL affectsContainedObjects;
	NSMutableArray *cachedTrackNodes;
	uint64_t revNumberAtCacheTime;
}

- (id)initTrackWithObject: (COObject*)container containedObjects: (BOOL)contained;

- (COHistoryTrackNode*)redo;
- (COHistoryTrackNode*)undo;

- (COHistoryTrackNode*)currentNode;
- (void)setCurrentNode: (COHistoryTrackNode*)node;

- (NSArray *)nodes;

/* Private */

- (COStore*)store;
- (BOOL)revisionIsOnTrack: (CORevision*)rev;
- (CORevision *)nextRevisionOnTrackAfter: (CORevision *)rev backwards: (BOOL)back;

@end


@interface COHistoryTrackNode : NSObject
{
	CORevision *revision;
	COHistoryTrack *ownerTrack;
}

- (NSDictionary *)metadata;
- (uint64_t)revisionNumber;
- (ETUUID *)UUID;
- (NSArray *)changedObjectUUIDs;

/* History graph */

- (COHistoryTrackNode*)parent;
- (COHistoryTrackNode*)child;
- (NSArray*)secondaryBranches;

/* Private */

- (CORevision*)underlyingRevision;
+ (COHistoryTrackNode*)nodeWithRevision: (CORevision*)aRevision owner: (COHistoryTrack*)anOwner;
@end