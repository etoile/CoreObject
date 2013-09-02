#import "COCommand.h"
#import "CORevisionID.h"

@interface COCommandSetCurrentVersionForBranch : COSingleCommand
{
    ETUUID *_branchUUID;
    CORevisionID *_oldRevisionID;
    CORevisionID *_newRevisionID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) CORevisionID *oldRevisionID;
@property (readwrite, nonatomic, copy) CORevisionID *revisionID;

@end
