#import "COEdit.h"

@class COBranchInfo;

/**
 * action which can undo the creation of a branch
 */
@interface COEditDeleteBranch : COEdit
{
    COBranchInfo *branch_;
}

- (id) initWithBranchPlist: (COBranchInfo *)aBranch
                      UUID: (ETUUID*)aUUID
                      date: (NSDate*)aDate
               displayName: (NSString*)aName;

@end
