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
    CORevision *currentCommit_;
    NSSet *branchCommits_;
}

- (id) initWithCommits: (NSSet*)stateTokens
         branchCommits: (NSSet*)tokensOnBranch
         currentCommit: (CORevision*)currentCommit
                 store: (COSQLiteStore*)aStore;
- (void) layoutGraph;

- (COSQLiteStore *)store;

- (NSSize) size;
- (void) drawWithHighlightedCommit: (CORevision *)aCommit;

- (CORevision *)commitAtPoint: (NSPoint)aPoint;

- (NSRect) rectForCommit:(CORevision *)aCommit;
- (NSArray *) commits;

@end
