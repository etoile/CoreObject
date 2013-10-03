#import <CoreObject/COCommand.h>

@interface COCommandUndeletePersistentRoot : COSingleCommand
@end

@interface COCommandCreatePersistentRoot : COCommandUndeletePersistentRoot
{
	@private
    CORevisionID *_revisionID;
}

/**
 * The initial revision ID that is never nil.
 */
@property (nonatomic, strong) CORevisionID *revisionID;

@end
