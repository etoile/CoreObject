/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandSetPersistentRootMetadata : COSingleCommand
{
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (nonatomic, copy) NSDictionary *oldMetadata;
@property (nonatomic, copy) NSDictionary *metadata;

@end
