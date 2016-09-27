#import "COPersistentRoot+Graphviz.h"
#import "CORevision+Graphviz.h"

@implementation COBranch (Graphviz)

- (void)show
{
    [self.currentRevision show];
}

- (void)showHistory
{
    [self.persistentRoot showHistory];
}

@end
