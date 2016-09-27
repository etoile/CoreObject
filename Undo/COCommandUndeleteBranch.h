/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandUndeleteBranch : COCommand
{
    ETUUID *_branchUUID;
}

@property (nonatomic, readwrite, copy) ETUUID *branchUUID;

@end
