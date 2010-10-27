/*
 ETEntityDescription.m
 
 Entity description in a model description framework inspired by FAME 
 (http://scg.unibe.ch/wiki/projects/fame)
 
 Copyright (C) 2009 Eric Wasylishen

 Author:  Eric Wasylishen <ewasylishen@gmail.com>
 Date:  July 2009
 License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "ETEntityDescription.h"
#import "ETCollection.h"
#import "ETCollection+HOM.h"
#import "ETPropertyDescription.h"
#import "ETReflection.h"
#import "ETValidationResult.h"
#import "NSObject+Model.h"
#import "Macros.h"
#import "EtoileCompatibility.h"

/**
 * A description of an "entity", which can either be a class or a prototype.
 */
@implementation ETEntityDescription

+ (NSString *) rootEntityDescriptionName
{
	return @"NSObject";
}

- (id)  initWithName: (NSString *)name
{
	self = [super initWithName: name];
	if (nil == self) return nil;

	_abstract = NO;
	_propertyDescriptions = [[NSMutableDictionary alloc] init];
	_parent = nil;
	return self;
}

- (void) dealloc
{
	DESTROY(_propertyDescriptions);
	[super dealloc];
}

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *selfDesc = [self newBasicEntityDescription];

	if ([[selfDesc name] isEqual: [ETEntityDescription className]] == NO) 
		return selfDesc;

	ETPropertyDescription *owner = 
		[ETPropertyDescription descriptionWithName: @"owner" type: (id)@"ETPackageDescription"];
	[owner setOpposite: (id)@"ETPackageDescription.entityDescriptions"];
	ETPropertyDescription *abstract = 
		[ETPropertyDescription descriptionWithName: @"abstract" type: (id)@"BOOL"];
	ETPropertyDescription *root = 
		[ETPropertyDescription descriptionWithName: @"root" type: (id)@"BOOL"];
	[root setDerived: YES];
	ETPropertyDescription *propertyDescriptions = 
		[ETPropertyDescription descriptionWithName: @"propertyDescriptions" type: (id)@"ETPropertyDescription"];
	[propertyDescriptions setMultivalued: YES];
	[propertyDescriptions setOpposite: (id)@"ETPropertyDescription.owner"];
	ETPropertyDescription *parent = 
		[ETPropertyDescription descriptionWithName: @"parent" type: (id)@"ETEntityDescription"];
	
	[selfDesc setPropertyDescriptions: A(owner, abstract, root, propertyDescriptions, parent)];
	
	return selfDesc;
}

- (BOOL) isEntityDescription
{
	return YES;
}

- (NSString *) typeDescription;
{
	return @"Entity";
}

- (BOOL) isAbstract
{
	return _abstract;
}

- (void) setAbstract: (BOOL)isAbstract
{
	_abstract = isAbstract;
}

- (BOOL) isRoot
{
	return [self parent] == nil;
}

- (NSArray *) propertyDescriptionNames
{
	return (id)[[[self propertyDescriptions] mappedCollection] name];
}

- (NSArray *) allPropertyDescriptionNames
{
	//NSLog(@"Called -allPropertyDescriptionNames %@ on %@", (id)[[[self allPropertyDescriptions] mappedCollection] name], self);
	return (id)[[[self allPropertyDescriptions] mappedCollection] name];
}

- (NSArray *) propertyDescriptions
{
	return [_propertyDescriptions allValues];
}

- (void) setPropertyDescriptions: (NSArray *)propertyDescriptions
{
	FOREACH([self propertyDescriptions], oldProperty, ETPropertyDescription *)
	{
		[oldProperty setOwner: nil];
	}
	[_propertyDescriptions release];
	
	_propertyDescriptions = [[NSMutableDictionary alloc] initWithCapacity:
		[propertyDescriptions count]];
	FOREACH(propertyDescriptions, propertyDescription, ETPropertyDescription *)
	{
		[self addPropertyDescription: propertyDescription];
	}
}

- (void) addPropertyDescription: (ETPropertyDescription *)propertyDescription
{
	ETEntityDescription *owner = [propertyDescription owner];

	if (nil != owner)
	{
		[owner removePropertyDescription: propertyDescription];
	}
	[propertyDescription setOwner: self];
	[_propertyDescriptions setObject: propertyDescription
							  forKey: [propertyDescription name]];
}

- (void) removePropertyDescription: (ETPropertyDescription *)propertyDescription
{
	[propertyDescription setOwner: nil];
	[_propertyDescriptions removeObjectForKey: [propertyDescription name]];
}

- (NSArray *) allPropertyDescriptions
{
	if ([self isRoot])
	{
		return [_propertyDescriptions allValues];
	}
	else
	{
		return [[[self parent] allPropertyDescriptions]
			arrayByAddingObjectsFromArray: [_propertyDescriptions allValues]];
	}
}

- (ETEntityDescription *) parent
{
	return _parent;
}

- (void) setParent: (ETEntityDescription *)parentDescription
{
	_parent = parentDescription;
}

- (ETPackageDescription *) owner
{
	return _owner;
}

- (void) setOwner: (ETPackageDescription *)owner
{
	_owner = owner;
}

- (ETPropertyDescription *)propertyDescriptionForName: (NSString *)name
{
	return [_propertyDescriptions valueForKey: name];
}

- (ETValidationResult *) validateValue: (id)value forKey: (NSString *)key
{
	return [[self propertyDescriptionForName: key] validateValue: value forKey: key];
}

- (BOOL) isPrimitive
{
	return NO;
}

- (BOOL) isCPrimitive
{
	return NO;
}

/* Inspired by the Java implementation of FAME */
- (void) checkConstraints: (NSMutableArray *)warnings
{
	int container = 0;

	FOREACH([self allPropertyDescriptions], propertyDesc, ETPropertyDescription *)
	{
		if ([propertyDesc isContainer])
			container++;
	}
	if (container > 1) 
	{
		[warnings addObject: [self warningWithMessage: 
			@"Found more than one container/composite relationship"]];
	}

	/* Primitives belongs to a package unlike FAME */
	if ([[self owner] isString])
	{
		[warnings addObject: [self warningWithMessage: 
			@"Failed to resolve owner (a package)"]];	
	}
	if ([self owner] == nil)
	{
		[warnings addObject: [self warningWithMessage: @"Miss an owner (a package)"]];	
	}

	if ([[self name] isEqual: [[self class] rootEntityDescriptionName]] == NO) 
	{
		if ([[self parent] isString])
		{
			[warnings addObject: [self warningWithMessage: 
				@"Failed to resolve parent"]];
		}
		// NOTE: C primitives have no parent unlike ObjC primitives
		if ([self parent] == nil && [self isCPrimitive] == NO)
		{
			[warnings addObject: [self warningWithMessage: @"Miss a parent"]];
		}
		if ([[self parent] isCPrimitive]) 
		{
			[warnings addObject: [self warningWithMessage: 
				@"C Primitives are not allowed to be parent"]];
		}
	}

	NSMutableSet *entityDescSet = [NSMutableSet setWithObject: self];
	ETEntityDescription *entityDesc = [self parent];

	while (entityDesc != nil)
	{
		if ([entityDescSet containsObject: entityDesc])
		{
			[warnings addObject: [self warningWithMessage: 
				@"Found a loop in the parent chain"]];
			break;
		}
		[entityDescSet addObject: entityDesc];
		entityDesc = [entityDesc parent];
	}

	/* We put it at the end to get the entity warnings first */
	FOREACH([self propertyDescriptions], propertyDesc2, ETPropertyDescription *)
	{
		[propertyDesc2 checkConstraints: warnings];
	}
}

- (BOOL) isOrdered
{
	return NO;
}

- (BOOL) isEmpty
{
	return ([_propertyDescriptions count] == 0);
}

- (id) content
{
	return _propertyDescriptions;
}

- (NSArray *) contentArray
{
	return [_propertyDescriptions allValues];
}

- (NSUInteger) count
{
	return [_propertyDescriptions count];
}

- (id) objectEnumerator
{
	return [_propertyDescriptions objectEnumerator];
}

@end


@implementation ETPrimitiveEntityDescription

- (BOOL) isPrimitive
{
	return YES;
}

- (NSString *) typeDescription
{
	return @"Primitive Entity";
}

@end

@implementation ETCPrimitiveEntityDescription

- (BOOL) isCPrimitive
{
	return YES;
}

- (NSString *) typeDescription
{
	return @"C Primitive Entity";
}

@end


#if 0
// Serialization

/**
 * Serialize the object using the ETModelDescription meta-meta model.
 */
- (NSDictionary *) _ETModelDescriptionSerializationOfObject: (id)obj withAlreadySerializedObjectsAndIds: 
{
	NSMutableDictionary *serialization = [NSMutableDictionary dictionary];
	id desc = [obj entityDescription];
	if (desc)
	{
		FOREACH([desc propertyDescriptions], propertyDescription, ETPropertyDescription *)
		{
			
		}
	}
	else if ([obj class] == [NSArray class]) // NSDictionary, NSNumber
	{
		return D(@"primitiveType", @"NSArray", 
		@"value", [[obj map] serialize...];
		}
		else if ([NSValueAdaptor blahBlahBlah] works..)
		{
			// serialize using value adapter stuff
		}
		return serialization;
		}
		
#endif
		
		
/**
 Very simple implementation of an adaptive model object that is causally 
 connected to its description. This means that changes to the entity description
 immediately take effect in the instance of ETAdaptiveModelObject.
 
 Causal connection is ensured through the implementation of
 -valueForProperty: and -setValue:forProperty:.
 */		
@implementation ETAdaptiveModelObject 

- (id) init
{
	SUPERINIT;
	_properties = [[NSMutableDictionary alloc] init];
	_description = [[ETEntityDescription alloc] initWithName: @"Untitled"];
	return self;
}

DEALLOC(DESTROY(_properties); DESTROY(_description);)

/* Property-value coding */
		
- (id) valueForProperty: (NSString *)key
{
	ETPropertyDescription *desc = [_description propertyDescriptionForName: key];
	if (desc != nil)
	{
		return [_properties valueForKey: key];
	}
	else
	{
		return nil;
	}
}
			
- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	ETPropertyDescription *desc = [_description propertyDescriptionForName: key];
	if (desc != nil && ![desc isDerived])
	{
		[_properties setValue:value forKey: key];
		return YES;
	}
	return NO;
}

- (NSArray *) propertyNames
{
	//FIXME: Optimize if needed.
	return (NSArray *)[[[_description propertyDescriptions] mappedCollection] name];
}
		
- (NSArray *) allPropertyNames
{
	return (NSArray *)[[[_description allPropertyDescriptions] mappedCollection] name];
}
		
/* Key-value coding */

- (id) valueForKey: (NSString *)key
{
	return [self valueForProperty: key];
}

@end
		
