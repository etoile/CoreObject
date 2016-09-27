/**
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  November 2010
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COCollection.h>
#import <CoreObject/COEditingContext.h>

/** 
 * @group Object Collection and Organization
 * @abstract COContainer is a mutable, ordered, strong (contained objects can 
 * only be in one COContainer) collection class.
 *
 * Unlike COGroup, COContainer can the same object multiple times at various 
 * indexes.
 */
@interface COContainer : COCollection
{

}

/** @taskunit Type Querying */

/**
 * Returns YES.
 */
@property (nonatomic, readonly) BOOL isContainer;

@end
