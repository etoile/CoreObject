#import <Foundation/Foundation.h>
#import <CoreObject/COType.h>

@class COObject;
@class COItem;

/**
 * An instance of this class is owned by each COObject,
 * to cache incoming relationships for that object.
 */
@interface CORelationshipCache : NSObject
{
@private
    NSMutableArray *_cachedRelationships;
}

/**
 * Returns an array of COObject which have a reference to the
 * owning COObject through the given property in the owning COObject.
 */
- (NSSet *) referringObjectsForPropertyInTarget: (NSString *)aProperty;

- (COObject *) referringObjectForPropertyInTarget: (NSString *)aProperty;

- (void) removeAllEntries;

- (void) removeReferencesForPropertyInSource: (NSString *)aTargetProperty
                                sourceObject: (COObject *)anObject;

- (void) addReferenceFromSourceObject: (COObject *)aReferrer
                       sourceProperty: (NSString *)aSource
                       targetProperty: (NSString *)aTarget;

@end
