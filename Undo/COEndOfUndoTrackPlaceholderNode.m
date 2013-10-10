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

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"metadata", @"UUID", @"persistentRootUUID", @"branchUUID", @"date",
		  @"localizedTypeDescription", @"localizedShortDescription")];
}

- (NSDictionary *)metadata { return nil; }
- (ETUUID *)UUID { return nil; }
- (ETUUID *)persistentRootUUID { return nil; }
- (ETUUID *)branchUUID { return nil; }
- (NSDate *)date { return nil; }

- (NSString *)localizedTypeDescription
{
	return _(@"Unknown");
}

- (NSString *)localizedShortDescription
{
	return _(@"Initial state");
}

@end
