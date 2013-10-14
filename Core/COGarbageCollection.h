/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  October 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>

@interface COObject (COGarbageCollection)

/** @taskunit Contained Objects based on the Metamodel */

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns an array containing all COObjects "strongly contained" by this one.
 * This means objects which are values for "composite" properties.
 */
- (NSArray *)allStronglyContainedObjects;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (NSArray*)embeddedOrReferencedObjects;

@end
