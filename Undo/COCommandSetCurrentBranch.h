#import <CoreObject/COCommand.h>

@interface COCommandSetCurrentBranch : COSingleCommand
{
    ETUUID *_oldBranchUUID;
    ETUUID *_newBranchUUID;
}

@property (nonatomic, copy) ETUUID *oldBranchUUID;
@property (nonatomic, copy) ETUUID *branchUUID;

@end
