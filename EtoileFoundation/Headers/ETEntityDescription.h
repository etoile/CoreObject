/*
 ETEntityDescription.h
 
 A model description framework inspired by FAME 
 (http://scg.unibe.ch/wiki/projects/fame)
 
 Copyright (C) 2009 Eric Wasylishen

 Author:  Eric Wasylishen <ewasylishen@gmail.com>
 Date:  July 2009
 License:  Modified BSD (see COPYING)
 */

#import <EtoileFoundation/ETPropertyValueCoding.h>
#import <EtoileFoundation/ETCollection.h>
#import <EtoileFoundation/ETModelElementDescription.h>

@class ETPackageDescription, ETPropertyDescription, ETValidationResult, ETUTI;

/**
 * A description of an "entity", which can either be a class or a prototype.
 */
@interface ETEntityDescription : ETModelElementDescription <ETCollection>
{
	BOOL _abstract;
	NSMutableDictionary *_propertyDescriptions;
	ETEntityDescription *_parent;
	ETPackageDescription *_owner;
}

/**
 * The name of the entity description that should end the parent chain of every 
 * entity description.
 *
 * This entity description is the Object primitive in the repository.
 *
 * Will be used by -checkConstraints:.
 */
+ (NSString *) rootEntityDescriptionName;

/** Returns YES. */
- (BOOL) isEntityDescription;
/** Returns 'Entity'. */
- (NSString *) typeDescription;

/* Property getters/setters */

/**
 * Whether or not this entity is a primitive (i.e. describes attributes and not 
 * relationships)
 *
 * Primitives include both object and C primitives. e.g. NSString, NSDate, 
 * NSInteger, float, etc.
 *
 * See also -[ETPropertyDescription isRelationship].
 */
- (BOOL) isPrimitive;
/**
 * Whether or not this entity is a C primitive (i.e. describes attributes whose 
 * values are not objects). e.g. NSInteger, float, etc.
 *
 * If YES is returned, -isPrimitive returns the same.
 *
 * See also -[ETPropertyDescription isPrimitive].
 */
- (BOOL) isCPrimitive;
/**
 * Whether or not this entity is abstract (i.e. can't be instantiated)
 */
- (BOOL) isAbstract;
- (void) setAbstract: (BOOL)isAbstract;
/**
 * Whether this is a root entity (has no parent entity)
 */
- (BOOL) isRoot;
/**
 * Names of the property descriptions (not including those declared in parent 
 * entities).
 */
- (NSArray *) propertyDescriptionNames;
/**
 * Names of all property descriptions including those declared in parent 
 * entities.
 */
- (NSArray *) allPropertyDescriptionNames;
/**
 * Descriptions of the properties declared on this entity (not including those
 * declared in parent entities)
 */
- (NSArray *) propertyDescriptions;
- (void) setPropertyDescriptions: (NSArray *)propertyDescriptions;
- (void) addPropertyDescription: (ETPropertyDescription *)propertyDescription;
- (void) removePropertyDescription: (ETPropertyDescription *)propertyDescription;

/**
 * Descriptions of the entity's properties, including those declared in parent
 * entities.
 */
- (NSArray *) allPropertyDescriptions;
/**
 * The parent entity of this entity. (Superclass or prototype)
 */
- (ETEntityDescription *) parent;
- (void) setParent: (ETEntityDescription *)parentDescription;
/** 
 * The package to which this entity belongs to.
 */
- (ETPackageDescription *) owner;
- (void) setOwner: (ETPackageDescription *)owner;

/* Utility methods */

- (ETPropertyDescription *)propertyDescriptionForName: (NSString *)name;

/* Validation */

- (ETValidationResult *) validateValue: (id)value forKey: (NSString *)key;

@end

/** Used to describe Model description primitives: object, string, boolean 
etc. See -[ETEntityDescription isPrimitive].

This class is used internally. You can possibly use it to support new 
primitives. */
@interface ETPrimitiveEntityDescription : ETEntityDescription
/** Returns YES. */
- (BOOL) isPrimitive;
@end

/** Used to describe Model description C primitives: float, BOOL, etc.
See -[ETEntityDescription isCPrimitive].

This class is used internally. You can possibly use it to support new 
primitives. */
@interface ETCPrimitiveEntityDescription : ETPrimitiveEntityDescription
/** Returns YES. */
- (BOOL) isCPrimitive;
@end

@interface ETAdaptiveModelObject : NSObject
{
	NSMutableDictionary *_properties;
	ETEntityDescription *_description;
}

- (id) valueForProperty: (NSString *)key;
- (BOOL) setValue: (id)value forProperty: (NSString *)key;

@end
