/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandDeletePersistentRoot : COCommand
{
@private
    ETUUID *_initialRevisionID;
}

/**
 * The persistent root initial revision ID if the command is a create inverse. 
 * See -[COCommandCreatePersistentRoot inverse].
 *
 * If the command is a undelete inverse or was not obtained using 
 * -[COCommand inverse], returns nil.
 */
@property (nonatomic, readwrite, copy) ETUUID *initialRevisionID;

@end
