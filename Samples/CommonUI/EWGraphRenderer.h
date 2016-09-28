/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  March 2014
    License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@protocol EWGraphRendererDelegate <NSObject>

- (NSArray *)allOrderedNodesToDisplayForTrack: (id <COTrack>)aTrack;
- (NSColor *)colorForNode: (id <COTrack>)aTrack isCurrentOrAncestorOfCurrent: (BOOL)current;
@end

@interface EWGraphRenderer : NSObject
{
    NSSet *uuids;
    NSArray *trackNodesChronological;
    NSMutableDictionary *rowIndexForUUID;
    NSMutableDictionary *revisionInfoForUUID;
    NSMutableDictionary *childrenForUUID;
    NSMutableDictionary *levelForUUID;
    NSMutableSet *currentUUIDAndAncestors;
    NSMutableArray *graphRows;

    id <COTrack> track;
}

- (void)updateWithTrack: (id <COTrack>)aTrack;

- (NSUInteger)count;
- (id <COTrackNode>)revisionAtIndex: (NSUInteger)index;
- (void)drawRevisionAtIndex: (NSUInteger)index inRect: (NSRect)aRect;

@property (nonatomic, readwrite, unsafe_unretained) id <EWGraphRendererDelegate> delegate;

@end
