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

/** 
 * @group Object Collection and Organization
 *
 * COContainer is a mutable, ordered, strong (contained objects can only be in 
 * one COContainer) collection class.
 */
@interface COContainer : COCollection
{

}

/**
 * Returns YES.
 */
- (BOOL)isContainer;

@end

/**
 * @group Object Collection and Organization
 *
 * COLibrary is used to represents libraries such as photo, music, tag etc.  
 * 
 * Contained objects can only be one library.
 *
 * Unlike COContainer, it is unordered.
 */
@interface COLibrary : COContainer
{

}

/**
 * Returns YES.
 */
- (BOOL)isLibrary;

@end
