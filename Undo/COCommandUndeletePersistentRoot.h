#import <CoreObject/COCommand.h>

@interface COCommandUndeletePersistentRoot : COSingleCommand
@end

@interface COCommandCreatePersistentRoot : COCommandUndeletePersistentRoot
{
	@private
    ETUUID *_initialRevisionID;
}

/**
 * The persistent root initial revision ID (never nil).
 */
@property (nonatomic, copy) ETUUID *initialRevisionID;

@end
