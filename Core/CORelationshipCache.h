#import <Foundation/Foundation.h>
#import "COType.h"

@class ETUUID;
@class COItem;


@interface CORelationshipRecord : NSObject
{
@private
    ETUUID *uuid_;
    NSString *property_;
}

+ (CORelationshipRecord *) recordWithUUID: (ETUUID *)aUUID property: (NSString *)aProp;

// FIXME: Make not mutable to the public
@property (readwrite, nonatomic, retain) ETUUID *uuid;
@property (readwrite, nonatomic, retain) NSString *property;
@end

/**
 * Simple wrapper around an NSMutableDictionary mapping COUUID's to mutable sets of COUUID's.
 */
@interface CORelationshipCache : NSObject
{
    NSMutableDictionary *embeddedObjectParentUUIDForUUID_;
    NSMutableDictionary *referrerUUIDsForUUID_;
    CORelationshipRecord *tempRecord_;
}

/**
 * @returns a set of CORelationshipRecord
 */
- (NSSet *) referrersForUUID: (ETUUID *)anObject;

- (CORelationshipRecord *) parentForUUID: (ETUUID *)anObject;

/**
 * @returns a set of COUUID
 */
- (NSSet *) referrersForUUID: (ETUUID *)anObject
            propertyInParent: (NSString*)propInParent;

#pragma mark modification

- (void) updateRelationshipCacheWithOldValue: (id)oldVal
                                     oldType: (COType)oldType
                                    newValue: (id)newVal
                                     newType: (COType)newType
                                 forProperty: (NSString *)aProperty
                                    ofObject: (ETUUID *)anObject;

- (void) clearOldValue: (id)oldVal
               oldType: (COType)oldType
           forProperty: (NSString *)aProperty
              ofObject: (ETUUID *)anObject;

- (void) setNewValue: (id)newVal
             newType: (COType)newType
         forProperty: (NSString *)aProperty
            ofObject: (ETUUID *)anObject;

- (void) addItem: (COItem *)anItem;
- (void) removeItem: (COItem *)anItem;

- (void) removeAllEntries;

@end
