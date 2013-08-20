#import <CoreObject/COEdit.h>

@interface COEditDeleteBranch : COSingleEdit
{
    ETUUID *_branchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;

@end
