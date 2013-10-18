/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  October 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObjectGraphContext.h>

@interface COObjectGraphContext (COGarbageCollection)

/**
 * @return The subset of -itemUUIDs that are reachable from [self rootObject].
 *
 * Reachable means there is a chain of inner object references starting at the
 * root object (doesn't matter if the references are composite or not) that are
 * persistent (the property description returns YES from -isPersistent)
 *
 * Throws an exception if [self rootObject] is nil.
 */
- (NSSet *) allReachableObjectUUIDs;

@end
