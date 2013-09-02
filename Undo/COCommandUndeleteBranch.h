#import <CoreObject/COCommand.h>

@interface COCommandUndeleteBranch : COSingleCommand
{
    ETUUID *_branchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;

@end
