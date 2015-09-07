/**
	Copyright (C) 2013 Eric Wasylishen

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

- (void) removeCachedOutgoingRelationshipsForCollectionValue: (id)obj
								   ofPropertyWithDescription: (ETPropertyDescription *)aProperty;

- (void) addCachedOutgoingRelationshipsForCollectionValue: (id)obj
								ofPropertyWithDescription: (ETPropertyDescription *)aProperty;

@end
