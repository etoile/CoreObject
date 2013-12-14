/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  September 2013
	License:  MIT  (see COPYING)
 */

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
