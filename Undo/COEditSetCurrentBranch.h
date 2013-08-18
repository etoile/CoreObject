#import "COEdit.h"

@interface COEditSetCurrentBranch : COEdit
{
    ETUUID *oldBranch_;
    ETUUID *newBranch_;

}

- (id) initWithOldBranchUUID: (ETUUID*)aOldBranchUUID
               newBranchUUID: (ETUUID*)aNewBranchUUID
                        UUID: (ETUUID*)aUUID
                        date: (NSDate*)aDate
                 displayName: (NSString*)aName;
@end
