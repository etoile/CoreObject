#import <CoreObject/COCommand.h>

@interface COCommandSetCurrentBranch : COSingleCommand
{
    ETUUID *_oldBranchUUID;
    ETUUID *_newBranchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *oldBranchUUID;
@property (readwrite, nonatomic, copy) ETUUID *branchUUID;

@end
