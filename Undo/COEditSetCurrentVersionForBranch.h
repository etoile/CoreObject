#import "COEdit.h"
#import "CORevisionID.h"

/**
 * undo setting from old -> new (to apply, replace new by old)
 */
@interface COEditSetCurrentVersionForBranch : COEdit
{
    ETUUID *_branchUUID;
    CORevisionID *_oldRevisionID;
    CORevisionID *_newRevisionID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) CORevisionID *oldRevisionID;
@property (readwrite, nonatomic, copy) CORevisionID *newRevisionID;

@end
