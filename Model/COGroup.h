/**
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  November 2010
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COCollection.h>

/**
 * @group Object Collection and Organization
 * @abstract COGroup is a mutable, ordered, weak (an object can be in any 
 * number of collections) collection class.
 *
 * Unlike COContainer, COGroup contains distinct objects, an object cannot 
 * appear multiple times at various indexes.
 *
 * COGroup is not unordered, to ensure the element ordering remains stable in 
 * the UI without sorting.
 */
@interface COGroup : COCollection


/** @taskunit Type Querying */


/**
 * Returns YES.
 */
@property (nonatomic, readonly) BOOL isGroup;

@end
