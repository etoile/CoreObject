#import <CoreObject/COEdit.h>

@interface COEditSetCurrentBranch : COEdit
{
    ETUUID *_oldBranchUUID;
    ETUUID *_newBranchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *oldBranchUUID;
@property (readwrite, nonatomic, copy) ETUUID *newBranchUUID;

@end
