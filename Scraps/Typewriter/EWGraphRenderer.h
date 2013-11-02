#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@interface EWGraphRenderer : NSObject
{
	NSSize size;
	NSMutableArray *allCommitsSorted;
	NSMutableDictionary *childrenForUUID;
	NSMutableDictionary *levelForUUID;
	NSUInteger maxLevelUsed;
	COSQLiteStore *store;
    
    // Used for coloring the graph
    CORevisionID *currentCommit_;
    NSSet *branchCommits_;
}

- (id) initWithCommits: (NSSet*)stateTokens
         branchCommits: (NSSet*)tokensOnBranch
         currentCommit: (CORevisionID*)currentCommit
                 store: (COSQLiteStore*)aStore;
- (void) layoutGraph;

- (COSQLiteStore *)store;

- (NSSize) size;
- (void) drawWithHighlightedCommit: (CORevisionID *)aCommit;

- (CORevisionID *)commitAtPoint: (NSPoint)aPoint;

- (NSRect) rectForCommit:(CORevisionID *)aCommit;
- (NSArray *) commits;

@end
