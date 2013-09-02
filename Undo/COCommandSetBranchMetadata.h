#import <CoreObject/COCommand.h>

@interface COCommandSetBranchMetadata : COSingleCommand
{
    ETUUID *_branchUUID;
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) NSDictionary *oldMetadata;
@property (readwrite, nonatomic, copy) NSDictionary *metadata;

@end
