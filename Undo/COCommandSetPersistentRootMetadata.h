/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandSetPersistentRootMetadata : COCommand
{
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (nonatomic, readwrite, copy) NSDictionary *oldMetadata;
@property (nonatomic, readwrite, copy) NSDictionary *metadata;

@end
