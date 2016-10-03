/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COType.h>

@class COObject, COItem;

NS_ASSUME_NONNULL_BEGIN

@interface COCachedRelationship : NSObject
{
@public
    NSString *_targetProperty;
    COObject *__weak _sourceObject;
    NSString *_sourceProperty;
}

@property (nonatomic, readonly) NSDictionary *descriptionDictionary;
@property (readwrite, nonatomic, weak) __kindof COObject *sourceObject;
@property (readwrite, nonatomic, copy) NSString *sourceProperty;
/**
 * The property whose value is looked up with the incoming relationship cache of the target object.
 *
 * For a unidirectional relationship without opposite, the target property is nil, since there is an 
 * outgoing relationship (from source to target), but no incoming relationship in the reverse 
 * direction.
 */
@property (readwrite, nonatomic, copy, nullable) NSString *targetProperty;

- (BOOL)isSourceObjectTrackingSpecificBranchForTargetObject: (COObject *)aTargetObject;

@property (nonatomic, readonly, getter=isSourceObjectBranchDeleted) BOOL sourceObjectBranchDeleted;

@end

/**
 * An instance of this class is owned by each COObject,
 * to cache incoming relationships for that object.
 */
@interface CORelationshipCache : NSObject
{
@private
    NSMutableArray *_cachedRelationships;
    COObject *__weak _owner;
}

- (instancetype)initWithOwner: (COObject *)owner NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSSet<__kindof COObject *> *referringObjects;

/**
 * Returns an array of COObject which have a reference to the
 * owning COObject through the given property in the owning COObject.
 */
- (NSSet *)referringObjectsForPropertyInTarget: (NSString *)aProperty;
- (__kindof COObject *)referringObjectForPropertyInTarget: (NSString *)aProperty;

- (void)removeAllEntries;

@property (nonatomic, readonly) NSArray *allEntries;

// FIXME: aTargetProperty sounds like an incorrect argument name... should be aSourceProperty?
- (void)removeReferencesForPropertyInSource: (NSString *)aTargetProperty
                               sourceObject: (COObject *)anObject;
- (void)addReferenceFromSourceObject: (COObject *)aReferrer
                      sourceProperty: (NSString *)aSource
                      targetProperty: (nullable NSString *)aTarget;

@end

NS_ASSUME_NONNULL_END
