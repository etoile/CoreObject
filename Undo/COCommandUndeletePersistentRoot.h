#import <CoreObject/COCommand.h>

@interface COCommandUndeletePersistentRoot : COSingleCommand
@end

@interface COCommandCreatePersistentRoot : COCommandUndeletePersistentRoot
{
	@private
    CORevisionID *_initialRevisionID;
}

/**
 * The persistent root initial revision ID (never nil).
 */
@property (nonatomic, strong) CORevisionID *initialRevisionID;

@end
