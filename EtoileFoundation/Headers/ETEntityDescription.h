/**
	<abstract>A model description framework inspired by FAME
	(http://scg.unibe.ch/wiki/projects/fame)</abstract>

	Copyright (C) 2009 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  July 2009
	License:  Modified BSD (see COPYING)
 */

#import <EtoileFoundation/ETPropertyValueCoding.h>
#import <EtoileFoundation/ETCollection.h>
#import <EtoileFoundation/ETModelElementDescription.h>

@class ETPackageDescription, ETPropertyDescription, ETValidationResult, ETUTI;

/** @group Model and Metamodel

A description of an entity, which can either be a class or a prototype. */
@interface ETEntityDescription : ETModelElementDescription <ETCollection, ETCollectionMutation>
{
	@private
	BOOL _abstract;
	NSMutableDictionary *_propertyDescriptions;
	ETEntityDescription *_parent;
	ETPackageDescription *_owner;
}
/** Self-description (aka meta-metamodel). */
+ (ETEntityDescription *) newEntityDescription;
/** The name of the entity description that should end the parent chain of 
every entity description.

This entity description is the Object primitive in the repository. See 
ETModelDescriptionRepository.

Will be used by -checkConstraints:. */
+ (NSString *) rootEntityDescriptionName;

/** @taskunit Querying Type */

/** Returns YES. */
- (BOOL) isEntityDescription;
/**  Returns <em>Entity</em>. */
- (NSString *) typeDescription;
/** Whether or not this entity is a primitive (i.e. describes attributes and 
not relationships).

Primitives include both object and C primitives. e.g. NSString, NSDate, 
NSInteger, float, etc.

See also -[ETPropertyDescription isRelationship]. */
- (BOOL) isPrimitive;
/** Whether or not this entity is a C primitive (i.e. describes attributes whose 
values are not objects). e.g. NSInteger, float, etc.

If YES is returned, -isPrimitive returns the same.

See also -[ETPropertyDescription isPrimitive]. */
- (BOOL) isCPrimitive;

/** @taskunit Model Specification */

/** Whether or not this entity is abstract (i.e. can't be instantiated). */
- (BOOL) isAbstract;
/** Whether or not this entity is abstract (i.e. can't be instantiated). */
- (void) setAbstract: (BOOL)isAbstract;

/** @taskunit Inheritance and Owning Package */

/** Whether this is a root entity (has no parent entity). */
- (BOOL) isRoot;
/** The parent entity of this entity. (Superclass or prototype) */
- (ETEntityDescription *) parent;
/** The parent entity of this entity. (Superclass or prototype) */
- (void) setParent: (ETEntityDescription *)parentDescription;
/** The package to which this entity belongs to. */
- (ETPackageDescription *) owner;
/** The package to which this entity belongs to. */
- (void) setOwner: (ETPackageDescription *)owner;

/** @taskunit Property Descriptions */

/** Names of the property descriptions (not including those declared in parent 
entities). */
- (NSArray *) propertyDescriptionNames;
/** Names of all property descriptions including those declared in parent 
entities. */
- (NSArray *) allPropertyDescriptionNames;
/** Descriptions of the properties declared on this entity (not including those
declared in parent entities). */
- (NSArray *) propertyDescriptions;
/** Descriptions of the properties declared on this entity (not including those 
declared in parent entities). */
- (void) setPropertyDescriptions: (NSArray *)propertyDescriptions;
/** Adds the given property description to this entity. */
- (void) addPropertyDescription: (ETPropertyDescription *)propertyDescription;
/** Removes the given property description from this entity. */
- (void) removePropertyDescription: (ETPropertyDescription *)propertyDescription;
/** Descriptions of the entity's properties, including those declared in parent 
entities. */
- (NSArray *) allPropertyDescriptions;
/** Returns the property description which matches the given name.

See also -[ETModelElementDescription name] which is inherited by 
ETPropertyDescription. */
- (ETPropertyDescription *)propertyDescriptionForName: (NSString *)name;

/** @taskunit Validation */

/** Tries to validate the value that corresponds to the given property name, 
by delegating the validation to the right property description, and returns a 
validation result object. */
- (ETValidationResult *) validateValue: (id)value forKey: (NSString *)key;

@end

/** @group Model and Metamodel

Used to describe Model description primitives: object, string, boolean 
etc. See -[ETEntityDescription isPrimitive].

This class is used internally. You can possibly use it to support new 
primitives. */
@interface ETPrimitiveEntityDescription : ETEntityDescription
/** Returns YES. */
- (BOOL) isPrimitive;
@end

/** @group Model and Metamodel

Used to describe Model description C primitives: float, BOOL, etc.
See -[ETEntityDescription isCPrimitive].

This class is used internally. You can possibly use it to support new 
primitives. */
@interface ETCPrimitiveEntityDescription : ETPrimitiveEntityDescription
/** Returns YES. */
- (BOOL) isCPrimitive;
@end

/** @group Model and Metamodel

WARNING: This class is under development and must be ignored.

Very simple implementation of an adaptive model object that is causally
connected to its description. This means that changes to the entity description 
immediately take effect in the instance of ETAdaptiveModelObject.

Causal connection is ensured through the implementation of -valueForProperty: 
and -setValue:forProperty:. */
@interface ETAdaptiveModelObject : NSObject
{
	@private
	NSMutableDictionary *_properties;
	ETEntityDescription *_description;
}

/** @taskunit Property Value Coding */

/** Returns the property value if the property is declared in the metamodel 
(aka entity description). */
- (id) valueForProperty: (NSString *)key;
/** Sets the property value and returns YES when the property is declared in 
the metamodel and it allows the value to be set. In all other cases, does 
nothing and returns NO. */ 
- (BOOL) setValue: (id)value forProperty: (NSString *)key;

@end
