#import <CoreObject/COEdit.h>

@interface COEditUndeleteBranch : COEdit
{
    ETUUID *_branchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;

@end
