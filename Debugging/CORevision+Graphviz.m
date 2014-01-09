#import "CORevision+Graphviz.h"
#import "CORevisionCache.h"
#import "COObjectGraphContext+Graphviz.h"

@implementation CORevision (Graphviz)

- (void) show
{
	[[cache.store itemGraphForRevisionUUID: self.UUID persistentRoot: self.persistentRootUUID] showGraph];
}

@end
