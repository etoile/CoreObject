#import "COBranchInfo.h"
#import "CORevisionID.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COBranchInfo

@synthesize UUID = uuid_;
@synthesize persistentRootUUID = _persistentRootUUID;
@synthesize initialRevisionID = initialRevisionId_;
@synthesize headRevisionID = headRevisionId_;
@synthesize currentRevisionID = currentRevisionId_;
@synthesize deleted = deleted_;
@synthesize metadata = metadata_;
@synthesize parentBranchUUID = parentBranchUUID_;

- (ETUUID *) initialRevisionUUID
{
	return [initialRevisionId_ revisionUUID];
}

- (ETUUID *) headRevisionUUID
{
	return [headRevisionId_ revisionUUID];
}

- (ETUUID *) currentRevisionUUID
{
	return [currentRevisionId_ revisionUUID];
}

- (void) setInitialRevisionUUID:(ETUUID *)aUUID
{
	initialRevisionId_ = [[CORevisionID alloc] initWithPersistentRootUUID: self.persistentRootUUID
															 revisionUUID: aUUID];
}

- (void) setHeadRevisionUUID:(ETUUID *)aUUID
{
	headRevisionId_ = [[CORevisionID alloc] initWithPersistentRootUUID: self.persistentRootUUID
															 revisionUUID: aUUID];
}

- (void) setCurrentRevisionUUID:(ETUUID *)aUUID
{
	currentRevisionId_ = [[CORevisionID alloc] initWithPersistentRootUUID: self.persistentRootUUID
															 revisionUUID: aUUID];
}

- (ETUUID *) remoteMirror
{
    NSString *value = metadata_[@"remoteMirror"];
    if (value != nil)
    {
        return [ETUUID UUIDWithString: value];
    }
    return nil;
}

- (ETUUID *) replcatedBranch
{
    NSString *value = metadata_[@"replcatedBranch"];
    if (value != nil)
    {
        return [ETUUID UUIDWithString: value];
    }
    return nil;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<Branch %@ <curr. rev.: %@> %@>", uuid_, currentRevisionId_, metadata_];
}

@end