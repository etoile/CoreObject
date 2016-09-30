/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COObject.h>

NS_ASSUME_NONNULL_BEGIN

@interface COObject (RelationshipCache)

- (void)updateCachedOutgoingRelationshipsForOldValue: (nullable id)oldVal
                                            newValue: (nullable id)newVal
                           ofPropertyWithDescription: (ETPropertyDescription *)aProperty;
- (void)removeCachedOutgoingRelationships;
- (void)removeCachedOutgoingRelationshipsForCollectionValue: (id)obj
                                  ofPropertyWithDescription: (ETPropertyDescription *)aProperty;
- (void)addCachedOutgoingRelationshipsForCollectionValue: (id)obj
                               ofPropertyWithDescription: (ETPropertyDescription *)aProperty;
- (void)removeCachedOutgoingRelationshipsForValue: (nullable id)aValue
                        ofPropertyWithDescription: (ETPropertyDescription *)aProperty;
- (void)addCachedOutgoingRelationshipsForValue: (nullable id)aValue
                     ofPropertyWithDescription: (ETPropertyDescription *)aProperty;

@end

NS_ASSUME_NONNULL_END
