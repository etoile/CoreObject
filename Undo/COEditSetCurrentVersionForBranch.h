#import "COEdit.h"
#import "CORevisionID.h"

/**
 * undo setting from old -> new (to apply, replace new by old)
 */
@interface COEditSetCurrentVersionForBranch : COEdit
{
    ETUUID *_branchUUID;
    CORevisionID *_oldCurrentRevision;
    CORevisionID *_newCurrentRevision;
}

- (id) initWithBranch: (ETUUID *)aBranch
             oldToken: (CORevisionID *)oldToken
             newToken: (CORevisionID *)newToken
                 UUID: (ETUUID*)aUUID
                 date: (NSDate*)aDate
          displayName: (NSString*)aName;

@end
