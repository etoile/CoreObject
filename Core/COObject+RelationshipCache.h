/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COObject.h>

@interface COObject (RelationshipCache)

- (void) updateCachedOutgoingRelationshipsForOldValue: (id)oldVal
                                             newValue: (id)newVal
                            ofPropertyWithDescription: (ETPropertyDescription *)aProperty;
- (void) removeCachedOutgoingRelationships;

@end
