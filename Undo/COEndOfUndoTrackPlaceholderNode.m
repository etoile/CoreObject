/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  October 2013
	License:  MIT  (see COPYING)
 */

#import "COEndOfUndoTrackPlaceholderNode.h"

@implementation COEndOfUndoTrackPlaceholderNode

static COEndOfUndoTrackPlaceholderNode *singleton;
static ETUUID *uuid;

+ (void) initialize
{
	NSAssert([COEndOfUndoTrackPlaceholderNode class] == self, @"Cannot subclass COEndOfUndoTrackPlaceholderNode");
    singleton = [[self alloc] init];
	
	// Even though COEndOfUndoTrackPlaceholderNode is an imaginary node,
	// give it a fixed UUID anyway, this makes it easier to draw a graph of
	// COTrackNode
	uuid = [ETUUID UUIDWithString: @"443D4D2D-2E9D-4560-8C00-01329290DA27"];
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

- (NSDictionary *)metadata { return [NSDictionary new]; }
- (ETUUID *)UUID { return uuid; }
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

- (id <COTrackNode>)parentNode { return nil; }
- (id <COTrackNode>)mergeParentNode { return nil; }

@end
