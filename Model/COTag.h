/**
	Copyright (C) 2013 Quentin Mathe

	Date:  March 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COGroup.h>
#import <CoreObject/COLibrary.h>

/**
 * @group Object Collection and Organization
 * @abstract COTag represents a tag attached to every object that belongs to 
 * it.
 *
 * The content is ordered (to ensure the tagged object order is  stable in the 
 * UI).
 *
 * To access and change the tagged objects, use COCollection API. For example, 
 * -content returns the tagged objects.
 *
 * A tag belongs to a COTagLibrary and can also belong to multiple COTagGroup.
 */
@interface COTag : COGroup
{

}


/** @taskunit Type Querying */


/**
 * Returns YES.
 */
@property (nonatomic, getter=isTag, readonly) BOOL tag;


/** @taskunit Tagging */


/**
 * Returns the tag the receiver represents.
 *
 * COTag can represent a tag attached to every object that belongs to it.
 *
 * By default, returns the name in lower case.
 */
@property (nonatomic, readonly) NSString *tagString;


/* @taskunit Tag Categories */


/**
 * The tag categories to which the tag belongs to.
 */
@property (nonatomic, readonly) NSSet *tagGroups;

@end


/**
 * @group Object Collection and Organization
 * @abstract COTagGroup is used to organize tags. 
 *
 * A tag group content is restricted to COTag objects. The content is ordered 
 * (to ensure the tag list order is  stable in the UI).
 *
 * To access and change the grouped tags, use COCollection API. For example, 
 * -content returns the tags belonging to the tag group.
 *
 * Tags can belong to multiple tag groups. Tag groups belong to a COTagLibrary.
 */
@interface COTagGroup : COGroup
{

}

@end


/**
 * @group Object Collection and Organization
 * @abstract COTagLibrary manages a large tag collection organized into tag 
 * groups.
 *
 * A tag library content is restricted to COTag objects.
 *
 * To access and change the library tags, use COCollection API. For example, 
 * -content returns all the tags in the libary.
 *
 * For organizing tags, see -tagGroups.
 *
 * Although multiple tag libraries can be created, it is usual to use a single 
 * library per CoreObject store. See -[COEditingContext tagLibrary].
 */
@interface COTagLibrary : COLibrary

/** @taskunit Organizing Tags */

/**
 * The tag categories used to organize the tags in the library.
 */
@property (copy, nonatomic) NSArray *tagGroups;

@end
