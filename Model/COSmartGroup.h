/**
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  November 2010
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COCollection.h>

typedef NSArray *(^COContentBlock)(void);

/**
 * @group Search
 * @abstract A custom group class whose content is provided by a predicate or
 * code block.
 *
 * COSmartGroup is an immutable, ordered, weak (an object can be in any number 
 * of collections) collection class.
 *
 * Because it is an immutable collection, it isn't a COCollection subclass.
 */
@interface COSmartGroup : COObject <ETCollection>
{
@private
    id <ETCollection> targetCollection;
    NSPredicate *predicate;
    COContentBlock contentBlock;
    NSArray *content;
}


/** @taskunit Controlling the Content */


/**
 * The target collection used to compute the smart group content.
 *
 * If a content block is provided, the target collection and predicate are ignored.
 *
 * If a predicate is provided and the target collection is filtered as an array 
 * using the predicate.
 *
 * If no content block or predicate are set, the target collection is used as is as
 * the smart group content.
 *
 * See -predicate and -contentBlock.
 */
@property (nonatomic, readwrite, strong) id <ETCollection> targetCollection;
/**
 * The predicate used to compute the smart group content.
 *
 * If a content block is provided, the predicate is ignored.
 *
 * If no target collection is set, the predicate is ignored.
 *
 * If a target collection is provided, see -targetCollection to know how the 
 * predicate is evaluated.
 *
 * See -targetCollection and -contentBlock.
 */
@property (nonatomic, readwrite, strong) NSPredicate *predicate;
/**
 * The content block used to compute the smart group content.
 *
 * If a content block is set, both the target collection and predicate are ignored.
 *
 * See -targetCollection and -predicate.
 */
@property (nonatomic, readwrite, copy) COContentBlock contentBlock;


/** @taskunit Accessing the Content */


/**
 * Returns the last computed smart group content.
 *
 * See -[ETCollection content].
 */
@property (nonatomic, readonly, strong) id content;


/** @taskunit Updating */


/**
 * Forces the receiver content to be recreated by evaluating the predicate
 * or content block.
 *
 * See also -predicate and -contentBlock.
 */
- (void)refresh;


/** @taskunit Object Matching */


/**
 * Returns the first object whose identifier matches.
 *
 * The search is shallow, in other words limited to the objects in the receiver 
 * content.
 *
 * See -[COObject identifier].
 */
- (id)objectForIdentifier: (NSString *)anId;


@end
