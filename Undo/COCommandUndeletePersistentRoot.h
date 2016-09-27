/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandUndeletePersistentRoot : COCommand
@end

@interface COCommandCreatePersistentRoot : COCommandUndeletePersistentRoot
{
    @private
    ETUUID *_initialRevisionID;
}

/**
 * The persistent root initial revision ID (never nil).
 */
@property (nonatomic, readwrite, copy) ETUUID *initialRevisionID;

@end
