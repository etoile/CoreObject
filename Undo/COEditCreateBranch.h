#import "COEdit.h"
#import "CORevisionID.h"

@interface COEditCreateBranch : COEdit
{
    ETUUID *_branchUUID;
    CORevisionID *_revisionID;
    // FIXME: Store branch metadata
}

@property (nonatomic, readwrite, copy) ETUUID *branchUUID;
@property (nonatomic, readwrite, copy) CORevisionID *revisionID;

@end
