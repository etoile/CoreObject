/*
 ETPropertyDescription.h
 
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

@class ETUTI, ETEntityDescription, ETPackageDescription, ETValidationResult;
@class ETRoleDescription;

/**
 * Description of an entity's property.
 */
@interface ETPropertyDescription : ETModelElementDescription
{
	@private
	BOOL _derived;
	BOOL _container;
	BOOL _multivalued;
	BOOL _ordered;
	ETPropertyDescription *_opposite;
	ETEntityDescription *_owner;
	ETPackageDescription *_package;
	ETEntityDescription *_type;
	ETRoleDescription *_role;
	BOOL _isSettingOpposite; /* Flag to exit when -setOpposite: is reentered */
}

/** Returns an autoreleased property description.

The given name and type must not be nil, otherwise an NSInvalidArgumentException 
is raised. */
+ (ETPropertyDescription *) descriptionWithName: (NSString *)aName 
                                           type: (ETEntityDescription *)aType;

/** Returns YES. */
- (BOOL) isPropertyDescription;
/** Returns 'Property (type of the value)'.

If -type returns a valid entity description, the parenthesis contains the 
entity name in the returned string. */
- (NSString *) typeDescription;

/* Properties */

/**
 * If YES, this property's value/values are the child/children of the entity
 * this property belongs to.
 *
 * isComposite is derived from opposite.isContainer
 *
 * See also -isContainer.
 */
- (BOOL) isComposite;
/**
 * If YES, this property's value is the parent of the entity this property
 * belongs to. 
 *
 * isContainer/isComposite describes an aggregate relationship where:
 * <deflist>
 * <term>isContainer</term><desc>is a child property and the to-one relationship 
 * to the parent</desc>
 * <term>isComposite</term><desc>is a parent property and the to-many 
 * relationship to the children</desc>
 * </deflist>
 */
- (BOOL) isContainer;
- (void) setIsContainer: (BOOL)isContainer;
- (BOOL) isDerived;
- (void) setDerived: (BOOL)isDerived;
- (BOOL) isMultivalued;
- (void) setMultivalued: (BOOL)isMultivalued;
- (BOOL) isOrdered;
- (void) setOrdered: (BOOL)isOrdered;
- (ETPropertyDescription *) opposite;
- (void) setOpposite: (ETPropertyDescription *)opposite;
- (ETEntityDescription *) owner;
- (void) setOwner: (ETEntityDescription *)owner;
- (ETPackageDescription *) package;
- (void) setPackage: (ETPackageDescription *)aPackage;
/** Returns the entity that describes the property's value.

This is the type of the attribute or destination entity.<br />
Whether the property is a relationship or an attribute depends on the returned 
entity. See -isRelationship. */
- (ETEntityDescription *) type;
/** Sets the entity that describes the property's value.

See -type. */
- (void) setType: (ETEntityDescription *)aType;


/** Returns YES when this property is a relationship to the destination entity 
returned by -type, otherwise returns NO when the property is an attribute.

When the destination entity is a primitive, then the property is an attribute 
unless the role is explicitly set to ETRelationshipRole.

isRelationship is derived from type.isPrimitive and role. */
- (BOOL) isRelationship;
/** Returns YES when the property is an attribute and NO when it is a 
relationship.

isAttribute is derived from isRelationship.

See -isRelationship. */
- (BOOL) isAttribute;

/* Validation */

- (id) role;
- (void) setRole: (ETRoleDescription *)role;

- (ETValidationResult *) validateValue: (id)value forKey: (NSString *)key;
/**
 * Pass a block which takes one argument (the value being validated)
 * and returns an ETValidationResult
 */
//- (void) setValidationBlock: (id)aBlock;

@end


/* Property Role Description classes 
 
 These allow a pluggable, more precise property description
 
 */
@interface ETRoleDescription : NSObject
{
}

- (ETPropertyDescription *) parent;
- (ETValidationResult *) validateValue: (id)value forKey: (NSString *)key;

@end

@interface ETRelationshipRole : ETRoleDescription
{
	BOOL _isMandatory;
	NSString *_deletionRule;
}

- (BOOL) isMandatory;
- (void) setMandatory: (BOOL)isMandatory;
- (NSString *) deletionRule;
- (void) setDeletionRule: (NSString *)deletionRule;

@end

@interface ETMultiOptionsRole : ETRoleDescription
{
	NSArray *_allowedOptions;
}

- (void) setAllowedOptions: (NSArray *)allowedOptions;
- (NSArray *) allowedOptions;

@end

@interface ETNumberRole : ETRoleDescription
{
	int _min;
	int _max;
}
- (int)minimum;
- (void)setMinimum: (int)min;
- (int)maximum;
- (void)setMaximum: (int)max;
@end
