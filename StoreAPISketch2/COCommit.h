#import <EtoileFoundation/EtoileFoundation.h>

@class COStore;


@interface COCommit : NSObject
{
	COStore *store;
}

- (ETUUID*)UUID;

- (NSDictionary*)metadata;

- (NSArray*)changedObjects;

- (ETUUID*)namedBranchForObject: (ETUUID*)object;

- (ETUUID*)parentCommitForObject: (ETUUID*)object;

- (ETUUID*)mergedCommitForObject: (ETUUID*)object;

- (NSArray*)childCommitsForObject: (ETUUID*)object;

- (NSDictionary*)valuesAndPropertiesForObject: (ETUUID*)object;

@end
