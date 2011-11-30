/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <ObjectMerging/COContainer.h>

@class COSmartGroup;

/**
 * @group Object Organization
 *
 * COGroup is an unordered, weak (an object can be in any number of collections)
 * collection class.
 */
@interface COGroup : COContainer // FIXME: it's only a subclass of COContainer to avoid code duplication, since the code is identical
{

}

/** @taskunit Collection Mutation Additions */

/**
 * Adds all the given objects to the receiver content.
 */
- (void)addObjects: (NSArray *)anArray;

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

/** @taskunit Object Matching */

/**
 * See -[COObjectMatching objectsMatchingQuery:].
 *
 * Object graph traversal implementation for COObjectMatching protocol.
 */
- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery;

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
