#import <CoreObject/COEdit.h>

@interface COEditSetBranchMetadata : COEdit
{
    ETUUID *_branchUUID;
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) NSDictionary *oldMetadata;
@property (readwrite, nonatomic, copy) NSDictionary *newMetadata;

@end
