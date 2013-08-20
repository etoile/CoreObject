#import <CoreObject/COEdit.h>

@interface COEditUndeleteBranch : COSingleEdit
{
    ETUUID *_branchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;

@end
