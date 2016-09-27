#import "COPersistentRoot+Graphviz.h"
#import "CORevision+Graphviz.h"
#import "CORevisionCache.h"
#import "COObjectGraphContext+Graphviz.h"
#import "COSQLiteStore+Graphviz.h"

@implementation COPersistentRoot (Graphviz)

- (void) show
{
    [self.currentRevision show];
}

- (void) showHistory
{
    [self.store showGraphForPersistentRootUUID: self.UUID];
}

@end
