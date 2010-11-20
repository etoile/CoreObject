#import <EtoileFoundation/EtoileFoundation.h>
#import "CONamedBranch.h"

@class COStore;

@interface COCommit : NSObject
{
	COStore *store;
	ETUUID *uuid;
}

- (ETUUID*)UUID;

- (NSDictionary*)metadata;

- (NSArray*)changedObjects;

- (CONamedBranch*)namedBranchForObject: (ETUUID*)object;

- (COCommit*)parentCommitForObject: (ETUUID*)object;

- (COCommit*)mergedCommitForObject: (ETUUID*)object;

- (NSArray*)childCommitsForObject: (ETUUID*)object;

- (NSDictionary*)valuesAndPropertiesForObject: (ETUUID*)object;

@end
