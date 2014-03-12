/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

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

@property (nonatomic, readwrite, unsafe_unretained) id<EWGraphRendererDelegate> delegate;

@end
