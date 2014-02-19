#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@interface EWGraphRenderer : NSObject
{
	NSArray *trackNodesChronological;
	NSMutableDictionary *rowIndexForUUID;
	NSMutableDictionary *revisionInfoForUUID;
	NSMutableDictionary *childrenForUUID;
	NSMutableDictionary *levelForUUID;
	NSMutableArray *graphRows;
	
	id<COTrack> track;
	
//	NSMutableDictionary *branchHeadForRevisionUUID;
//	NSMutableDictionary *branchCurrentForRevisionUUID;
}

- (void) updateWithTrack: (id<COTrack>)aTrack;

- (NSUInteger) count;
- (id<COTrackNode>) revisionAtIndex: (NSUInteger)index;
- (void) drawRevisionAtIndex: (NSUInteger)index inRect: (NSRect)aRect;

//- (NSArray *) branchesForIndex: (NSUInteger) index;

@end
