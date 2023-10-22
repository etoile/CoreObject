#import "CORevision+Graphviz.h"
#import "CORevisionCache.h"
#import "COObjectGraphContext+Graphviz.h"

@interface CORevision ()
- (CORevisionCache *)cache;
@end

@implementation CORevision (Graphviz)

- (void)show
{
    [[[self cache].store itemGraphForRevisionUUID: self.UUID
                                   persistentRoot: self.persistentRootUUID] showGraph];
}

@end
