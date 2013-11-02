#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@class EWGraphRenderer;

@interface EWHistoryGraphView : NSView
{
	EWGraphRenderer *graphRenderer;
    
    NSMutableArray *trackingRects;
    
    CORevisionID *mouseoverCommit;
}

- (void)  setPersistentRoot: (COPersistentRoot *)proot
                     branch: (COBranch*)aBranch
                      store: (COSQLiteStore*)aStore;

@end
