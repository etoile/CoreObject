#import <Foundation/Foundation.h>
#import <CoreObject/COObject.h>

@interface COObject (RelationshipCache)

- (void) updateCachedOutgoingRelationshipsForOldValue: (id)oldVal
                                             newValue: (id)newVal
                            ofPropertyWithDescription: (ETPropertyDescription *)aProperty;
- (void) addCachedOutgoingRelationships;
- (void) removeCachedOutgoingRelationships;

@end
