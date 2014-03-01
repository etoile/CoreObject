#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@protocol EWGraphRendererDelegate <NSObject>
- (NSArray *) allOrderedNodesToDisplayForTrack: (id<COTrack>)aTrack;
@end

@interface EWGraphRenderer : NSObject
{
	NSArray *trackNodesChronological;
	NSMutableDictionary *rowIndexForUUID;
	NSMutableDictionary *revisionInfoForUUID;
	NSMutableDictionary *childrenForUUID;
	NSMutableDictionary *levelForUUID;
	NSMutableArray *graphRows;
	
	id<COTrack> track;
}

- (void) updateWithTrack: (id<COTrack>)aTrack;

- (NSUInteger) count;
- (id<COTrackNode>) revisionAtIndex: (NSUInteger)index;
- (void) drawRevisionAtIndex: (NSUInteger)index inRect: (NSRect)aRect;

@property (nonatomic, readwrite, weak) id<EWGraphRendererDelegate> delegate;

@end
