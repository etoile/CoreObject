#import "COEdit.h"
#import "CORevisionID.h"

// FIXME: Do we even need this? All you should be able to do via the undo system
// is delete/undelete, which don't need to know revisionID or metadata,
// they just flip the deleted flag.

@interface COEditCreateBranch : COEdit
{
    ETUUID *_branchUUID;
    CORevisionID *_revisionID;
    NSDictionary *_metadata;
}

@property (nonatomic, readwrite, copy) ETUUID *branchUUID;
@property (nonatomic, readwrite, copy) CORevisionID *revisionID;
@property (nonatomic, readwrite, copy) NSDictionary *metadata;

@end
