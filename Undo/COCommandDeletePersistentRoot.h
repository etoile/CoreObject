#import <CoreObject/COCommand.h>

@interface COCommandDeletePersistentRoot : COSingleCommand
{
	@private
    CORevisionID *_revisionID;
}

/**
 * The initial revision ID if the command is a create inverse. See 
 * -[COCommandCreatePersistentRoot inverse].
 *
 * If the command is a undelete inverse or was not obtained using 
 * -[COCommand inverse], returns nil.
 */
@property (nonatomic, strong) CORevisionID *revisionID;

@end
