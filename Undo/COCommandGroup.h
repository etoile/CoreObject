#import <Foundation/Foundation.h>
#import <CoreObject/COCommand.h>

@class COCommitDescriptor;

/**
 * @group Undo Actions
 * @abstract A command group represents a commit done in an editing context
 *
 * See COCommand for a detailed presentation.
 */
@interface COCommandGroup : COCommand <ETCollection>
{
	@private
    NSMutableArray *_contents;
	NSDictionary *_metadata;
}

/**
 * The atomic commands grouped in the receiver for a commit. 
 *
 * Cannot contain COCommandGroup objects.
 */
@property (nonatomic, copy) NSMutableArray *contents;
/**
 * The commit metadata.
 */
@property (nonatomic, copy) NSDictionary *metadata;
/**
 * The commit descriptor matching the commit identifier in -metadata.
 *
 * COCommand overrides -localizedTypeDescription and -localizedShortDescription 
 * to return the equivalent commit descriptor descriptions.
 */
@property (nonatomic, readonly) COCommitDescriptor *commitDescriptor;

@end
