/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <ObjectMerging/COCollection.h>

@class COSmartGroup;

/**
 * @group Object Organization
 *
 * COGroup is a mutable, unordered, weak (an object can be in any number of 
 * collections) collection class.
 */
@interface COGroup : COCollection
{

}

/** @taskunit Tagging */

/**
 * Returns whether the receiver is a tag or not.
 *
 * A tag is group that belongs to -[COEditingContext tagGroup].
 */
- (BOOL)isTag;
/**
 * Returns the tag the receiver represents.
 *
 * COGroup can represent a tag attached to every object that belongs to the group.
 *
 * By default, returns the name in lower case.
 */
- (NSString *)tagString;
/**
 * Returns the first subgroup whose tag string matches.
 *
 * The search is shallow, in other words limited to the objects in the receiver 
 * content.
 */
- (COGroup *)groupForTagString: (NSString *)aTag;

@end

typedef NSArray *(^COContentBlock)(void);

/**
 * @group Object Organization
 *
 * A custom group class whose content is provided a query or a code block.
 */
@interface COSmartGroup : COObject <ETCollection>
{
	@private
	COGroup *targetGroup;
	COQuery *query;
	COContentBlock contentBlock;
	NSArray *content;
}

/** @taskunit Controlling the Content */

@property (nonatomic, retain) COGroup *targetGroup;
@property (nonatomic, retain) COQuery *query;
@property (nonatomic, copy) COContentBlock contentBlock;

/** @taskunit Accessing the Content */

- (id) content;

/** @taskunit Updating */

/**
 * Forces the receiver content to be recreated by evaluating the query or 
 * content block.
 *
 * See also -query and -contentBlock.
 */
- (void) refresh;

@end
