/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>

@class CORelationshipCache, COObjectGraphContext;

NS_ASSUME_NONNULL_BEGIN

void SetterToProperty(const char *setter, size_t setterlen, char *prop);
BOOL IsSetter(const char *selname, size_t sellen);

BOOL isSerializablePrimitiveValue(id value);
BOOL isSerializableScalarValue(id value);

ETEntityDescription *entityDescriptionForObjectInRepository(id anObject, ETModelDescriptionRepository *repo);

@interface COObject ()


/** @taskunit Initialization */


- (nullable Class)coreObjectCollectionClassForPropertyDescription: (ETPropertyDescription *)propDesc;
/**
 * Returns a new mutable dictionary to store properties.
 *
 * For multivalued properties not bound to an instance variable, the returned 
 * dictionary contains mutable collections that matches the metamodel.
 * 
 */
- (NSMutableDictionary *)newVariableStorage;
/**
 * Prepares an object to be initialized or deserialized.
 *
 * COObject initialization is broken in two steps:
 * 
 * <list>
 * <item>For a new object, prepare and initialize using the designated 
 * initializer (-initWithObjectGraphContext: or some other subclass designated 
 * initializer)</item>
 * <item>For loading an object, prepare and deserialize using -setStoreItem: 
 * (see -[COObjectGraphContext objectWithUUID:entityDescription:])</item>
 * </list>
 */
- (id)prepareWithUUID: (ETUUID *)aUUID
    entityDescription: (ETEntityDescription *)anEntityDescription
   objectGraphContext: (COObjectGraphContext *)aContext
                isNew: (BOOL)inserted  __attribute__((objc_method_family(init)));

@property (nonatomic, readonly) NSDictionary<NSString *, ETUUID *> *additionalStoreItemUUIDs;


/** @taskunit Status */


- (void)makeZombie;

@property (nonatomic, readonly, getter=isLoadingEnabled) BOOL loadingEnabled;


/** @taskunit Variable Storage */


- (nullable id)valueForStorageKey: (NSString *)key;
- (nullable id)valueForStorageKey: (NSString *)key shouldLoad: (BOOL)shouldLoad;
- (nullable id)serializableValueForStorageKey: (NSString *)key;
- (void)setValue: (nullable id)value forStorageKey: (NSString *)key;
- (nullable id)valueForProperty: (NSString *)key shouldLoad: (BOOL)shouldLoad;


/** @taskunit Mutating Collections */


/**
 * Checks the collection to mutate, and the indexes that goes along, both 
 * respect the metamodel constraints.
 *
 * On success, returns the collection, otherwise raises an exception.
 */
- (id)collectionForProperty: (NSString *)key mutationIndexes: (NSIndexSet *)indexes;
/** 
 * This method is only exposed to be used internally by COObject e.g. 
 * -updateCompositeRelationshipForPropertyDescription: (don't use in subclasses).
 *
 * Checks the insertion and the object that goes along respect the metamodel 
 * constraints, then calls 
 * -willChangeValueForProperty:atIndexes:withObjects:mutationKind:, then 
 * -insertObjects:atIndexes:hints: on the collection 
 * bound to the property, and 
 * -didChangeValueForProperty:atIndexes:withObjects:mutationKind:.
 *
 * See also ETCollectionMutation. 
 */
- (void)insertObjects: (NSArray *)objects
            atIndexes: (NSIndexSet *)indexes
                hints: (NSArray *)hints
          forProperty: (NSString *)key;
/** 
 * This method is only exposed to be used internally by COObject e.g. 
 * -updateCompositeRelationshipForPropertyDescription: (don't use in subclasses).
 *
 * Checks the removal and the object that goes along respect the metamodel 
 * constraints, then calls 
 * -willChangeValueForProperty:atIndexes:withObjects:mutationKind:, then 
 * -removeObjects:atIndexes:hints: on the collection 
 * bound to the property, and 
 * -didChangeValueForProperty:atIndexes:withObjects:mutationKind:.
 *
 * See also ETCollectionMutation. 
 */
- (void)removeObjects: (NSArray *)objects
            atIndexes: (NSIndexSet *)indexes
                hints: (NSArray *)hints
          forProperty: (NSString *)key;


/** @taskunit Relationship Cache */


@property (nonatomic, readonly) NSSet<__kindof COObject *> *referringObjects;
@property (nonatomic, readonly, strong) CORelationshipCache *incomingRelationshipCache;


/** @taskunit Cross Persistent Root References */


- (void)replaceReferencesToObjectIdenticalTo: (nullable COObject *)anObject
                                  withObject: (nullable COObject *)aReplacement;

@end

NS_ASSUME_NONNULL_END
