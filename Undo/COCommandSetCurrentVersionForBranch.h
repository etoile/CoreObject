#import "COCommand.h"

@class CORevision;

@interface COCommandSetCurrentVersionForBranch : COSingleCommand
{
    ETUUID *_branchUUID;
    ETUUID *_oldRevisionUUID;
    ETUUID *_newRevisionUUID;
	
	ETUUID *_oldHeadRevisionUUID;
    ETUUID *_newHeadRevisionUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) ETUUID *oldRevisionUUID;
@property (readwrite, nonatomic, copy) ETUUID *revisionUUID;

@property (readwrite, nonatomic, copy) ETUUID *oldHeadRevisionUUID;
@property (readwrite, nonatomic, copy) ETUUID *headRevisionUUID;


@property (nonatomic, readonly) CORevision *oldRevision;
@property (nonatomic, readonly) CORevision *revision;

@end
