#import "COEdit.h"

@interface COEditSetBranchMetadata : COEdit
{
    ETUUID *branch_;
    NSDictionary *old_;
    NSDictionary *new_;
}

- (id) initWithOldMetadata: (NSDictionary *)oldMeta
               newMetadata: (NSDictionary *)newMeta
                      UUID: (ETUUID*)aUUID
                branchUUID: (ETUUID*)aBranch
                      date: (NSDate*)aDate
               displayName: (NSString*)aName;
@end
