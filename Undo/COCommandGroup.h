/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COCommand.h>

@class COCommitDescriptor;

/**
 * @group Undo
 * @abstract A command group represents a commit done in an editing context
 *
 * See COCommand for a detailed presentation.
 */
@interface COCommandGroup : COCommand <ETCollection>
{
	@private
	ETUUID *_UUID;
    NSMutableArray *_contents;
	NSDictionary *_metadata;
    NSDate *_timestamp;
}


/** @taskunit Basic Properties */


/**
 * The commit UUID. 
 *
 * Allows an in-memory instance to be unambiguously mapped to a row in the SQL 
 * database behind COUndoTrack. Generated when the command is created, persists
 * across reads and writes to the database, but not preserved across calls to 
 * -inverse.
 */
@property (nonatomic, copy) ETUUID *UUID;
/**
 * The atomic commands grouped in the receiver for a commit. 
 *
 * Cannot contain COCommandGroup objects.
 */
@property (nonatomic, copy) NSMutableArray *contents;
/**
 * The commit metadata.
 */
@property (nonatomic, copy) NSDictionary *metadata;
/**
 * The commit descriptor matching the commit identifier in -metadata.
 *
 * COCommand overrides -localizedTypeDescription and -localizedShortDescription 
 * to return the equivalent commit descriptor descriptions.
 */
@property (nonatomic, readonly) COCommitDescriptor *commitDescriptor;
/**
 * The commit time.
 */
@property (nonatomic, copy) NSDate *timestamp;


@end
