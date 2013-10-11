/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COGroup.h>
#import <CoreObject/COLibrary.h>

/**
 * @group Object Collection and Organization
 *
 * COTag represents a tag attached to every object that belongs to it.
 */
@interface COTag : COGroup
{

}

/**
 * Returns YES.
 *
 * A tag is group that belongs to -[COEditingContext tagGroup].
 */
- (BOOL)isTag;

/** @taskunit Tagging */

/**
 * Returns the tag the receiver represents.
 *
 * COTag can represent a tag attached to every object that belongs to it.
 *
 * By default, returns the name in lower case.
 */
- (NSString *)tagString;

/* @taskunit Tag Categories */

/**
 * The tag categories to which the tag belongs to.
 */
@property (nonatomic, readonly) NSSet *tagGroups;

@end

/**
 * @group Object Collection and Organization
 *
 * COTagGroup is used to organize tags. 
 *
 * A tag group content is restricted to COTag objects.<br />
 * The content is ordered (to ensure the tag list order is  stable in the UI).
 *
 * Tags can be belong to multiple tag groups.
 */
@interface COTagGroup : COGroup
{

}

@end

/**
 * @group Object Collection and Organization
 *
 * COTagLibrary manages a large tag collection organized into tag groups.
 *
 * Although multiple tag libraries can be created, it is usual to use a single 
 * library per CoreObject store. See -[COEditingContext tagLibrary].
 */
@interface COTagLibrary : COLibrary
{
	@private
	NSMutableArray *_tagGroups;
}

/**
 * The tag categories used to organize the tags in the library.
 */
@property (copy, nonatomic) NSArray *tagGroups;

@end
