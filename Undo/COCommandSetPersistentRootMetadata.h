#import <CoreObject/COCommand.h>

@interface COCommandSetPersistentRootMetadata : COSingleCommand
{
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (nonatomic, copy) NSDictionary *oldMetadata;
@property (nonatomic, copy) NSDictionary *metadata;

@end
