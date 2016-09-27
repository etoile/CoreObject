#import "COPersistentRoot+Graphviz.h"
#import "CORevision+Graphviz.h"
#import "CORevisionCache.h"
#import "COObjectGraphContext+Graphviz.h"
#import "COSQLiteStore+Graphviz.h"

@implementation COBranch (Graphviz)

- (void) show
{
    [self.currentRevision show];
}

- (void) showHistory
{
    [self.persistentRoot showHistory];
}

@end
