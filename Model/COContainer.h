/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COCollection.h>
#import <CoreObject/COEditingContext.h>

/** 
 * @group Object Collection and Organization
 *
 * COContainer is a mutable, ordered, strong (contained objects can only be in 
 * one COContainer) collection class.
 *
 * Unlike COGroup, COContainer can the same object multiple times at various 
 * indexes.
 */
@interface COContainer : COCollection
{

}

/**
 * Returns YES.
 */
- (BOOL)isContainer;

@end
