#import "COEndOfUndoTrackPlaceholderNode.h"

@implementation COEndOfUndoTrackPlaceholderNode

static COEndOfUndoTrackPlaceholderNode *singleton;

+ (void) initialize
{
	NSAssert([COEndOfUndoTrackPlaceholderNode class] == self, @"Cannot subclass COEndOfUndoTrackPlaceholderNode");
    singleton = [[self alloc] init];
}

+ (COEndOfUndoTrackPlaceholderNode *) sharedInstance
{
	return singleton;
}

- (NSDictionary *)metadata { return nil; }
- (CORevisionID *)UUID { return nil; }
- (ETUUID *)persistentRootUUID { return nil; }
- (ETUUID *)branchUUID { return nil; }
- (NSDate *)date { return nil; }

@end
