#import "COEdit.h"
#import "CORevisionID.h"

@interface COEditSetCurrentVersionForBranch : COSingleEdit
{
    ETUUID *_branchUUID;
    CORevisionID *_oldRevisionID;
    CORevisionID *_newRevisionID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) CORevisionID *oldRevisionID;
@property (readwrite, nonatomic, copy) CORevisionID *newRevisionID;

@end
