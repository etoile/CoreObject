#import "COCommand.h"
#import "CORevisionID.h"

@class CORevision;

@interface COCommandSetCurrentVersionForBranch : COSingleCommand
{
    ETUUID *_branchUUID;
    CORevisionID *_oldRevisionID;
    CORevisionID *_newRevisionID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) CORevisionID *oldRevisionID;
@property (readwrite, nonatomic, copy) CORevisionID *revisionID;

@property (nonatomic, readonly) CORevision *oldRevision;
@property (nonatomic, readonly) CORevision *revision;

@end
