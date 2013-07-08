#import <Foundation/Foundation.h>
#import "COPersistentRoot.h"

@interface COPersistentRoot (RelationshipCache)

- (void) updateCachedOutgoingRelationshipsForOldValue: (id)oldVal
                                             newValue: (id)newVal
                            ofPropertyWithDescription: (ETPropertyDescription *)aProperty
                                             ofObject: (COObject *)anObject;
- (void) addCachedOutgoingRelationshipsForObject: (COObject *)anObject;
- (void) removeCachedOutgoingRelationshipsForObject: (COObject *)anObject;

@end
