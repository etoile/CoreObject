#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@interface EWGraphRenderer : NSObject
{
	NSArray *revisionInfosChronological;
	NSMutableDictionary *revisionInfoForUUID;
	NSMutableDictionary *childrenForUUID;
	NSMutableDictionary *levelForUUID;
	
	COPersistentRoot *persistentRoot;
}

- (void) updateWithProot: (COPersistentRoot *)proot;

- (NSUInteger) count;
- (CORevision *) revisionAtIndex: (NSUInteger)index;
- (void) drawRevisionAtIndex: (NSUInteger)index inRect: (NSRect)aRect;


@end
