#import <CoreObject/COCommand.h>

@interface COCommandSetPersistentRootMetadata : COSingleCommand
{
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (readwrite, nonatomic, copy) NSDictionary *oldMetadata;
@property (readwrite, nonatomic, copy) NSDictionary *metadata;

@end
