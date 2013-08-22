#import <CoreObject/COEdit.h>

@interface COEditSetCurrentBranch : COSingleEdit
{
    ETUUID *_oldBranchUUID;
    ETUUID *_newBranchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *oldBranchUUID;
@property (readwrite, nonatomic, copy) ETUUID *branchUUID;

@end
