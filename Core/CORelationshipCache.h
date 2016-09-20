/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COType.h>

@class COObject;
@class COItem;

@interface COCachedRelationship : NSObject
{
@public
	NSString *_targetProperty;
	/**
	 * Weak reference.
	 */
	COObject *__weak _sourceObject;
	NSString *_sourceProperty;
}

@property (nonatomic, readonly) NSDictionary *descriptionDictionary;

@property (readwrite, nonatomic, weak) COObject *sourceObject;
@property (readwrite, nonatomic, copy) NSString *sourceProperty;
@property (readwrite, nonatomic, copy) NSString *targetProperty;

- (BOOL) isSourceObjectTrackingSpecificBranchForTargetObject: (COObject *)aTargetObject;
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

- (instancetype) initWithOwner: (COObject *)owner NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSSet *referringObjects;

/**
 * Returns an array of COObject which have a reference to the
 * owning COObject through the given property in the owning COObject.
 */
- (NSSet *) referringObjectsForPropertyInTarget: (NSString *)aProperty;

- (COObject *) referringObjectForPropertyInTarget: (NSString *)aProperty;

- (void) removeAllEntries;

@property (nonatomic, readonly) NSArray *allEntries;

- (void) removeReferencesForPropertyInSource: (NSString *)aTargetProperty
                                sourceObject: (COObject *)anObject;

- (void) addReferenceFromSourceObject: (COObject *)aReferrer
                       sourceProperty: (NSString *)aSource
                       targetProperty: (NSString *)aTarget;

@end
