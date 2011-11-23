/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <ObjectMerging/COObject.h>

/**
 * COContainer is a COObject subclass which has an ordered, strong container
 * (contained objects can only be in one COContainer).
 */
@interface COContainer : COObject <ETCollection, ETCollectionMutation>
{
}

@end
