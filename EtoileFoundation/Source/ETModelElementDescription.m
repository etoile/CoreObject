/*
	Copyright (C) 2009 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  July 2009
	License:  Modified BSD (see COPYING)
 */

#import "ETModelElementDescription.h"
#import "ETEntityDescription.h"
#import "ETModelDescriptionRepository.h"
#import "ETPropertyDescription.h"
#import "ETUTI.h"
#import "NSObject+Model.h"
#import "Macros.h"
#import "EtoileCompatibility.h"


@implementation ETModelElementDescription

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *selfDesc = [self newBasicEntityDescription];

	if ([[selfDesc name] isEqual: [ETModelElementDescription className]] == NO) 
		return selfDesc;
	
	ETPropertyDescription *name = 
		[ETPropertyDescription descriptionWithName: @"name" type: (id)@"NSString"];
	ETPropertyDescription *fullName = 
		[ETPropertyDescription descriptionWithName: @"fullName" type: (id)@"NSString"];
	[fullName setDerived: YES];
	// TODO: To support overriden property descriptions would allow to declare 
	// 'owner' at the abstract class level too (as FM3 spec does).
	//ETPropertyDescription *owner = [ETPropertyDescription descriptionWithName: @"owner"];
	//[owner setDerived: YES];
	ETPropertyDescription *itemIdentifier = 
		[ETPropertyDescription descriptionWithName: @"itemIdentifier" type: (id)@"NSString"];
	ETPropertyDescription *typeDescription = 
		[ETPropertyDescription descriptionWithName: @"typeDescription" type: (id)@"NSString"];

	[selfDesc setAbstract: YES];	
	[selfDesc setPropertyDescriptions: A(name, fullName, itemIdentifier, typeDescription)];

	return selfDesc;
}

+ (id) descriptionWithName: (NSString *)name
{
	return [[[[self class] alloc] initWithName: name] autorelease];
}

- (id) initWithName: (NSString *)name
{
	if ([[self class] isMemberOfClass: [ETModelElementDescription class]])
	{
		DESTROY(self);
		return nil;
	}
	NILARG_EXCEPTION_TEST(name);
	// TODO: Check the name is not in use once we have a repository.

	SUPERINIT;
	ASSIGN(_name, name);
	return self;
}

- (void) dealloc
{
	DESTROY(_name);
	DESTROY(_itemIdentifier);
	[super dealloc];
}

- (BOOL) isPropertyDescription
{
	return NO;
}

- (BOOL) isEntityDescription
{
	return NO;
}

- (BOOL) isPackageDescription
{
	return NO;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@ %@", [super description], [self fullName]];
}

- (NSString *) name
{
	return _name;
}

- (void) setName: (NSString *)name
{
	ASSIGN(_name, name);
}

- (NSString *) fullName
{
	if (nil != [self owner])
	{
		return [NSString stringWithFormat: @"%@.%@", [[self owner] fullName], [self name]];
	}
	else
	{
		return [self name];
	}
}

- (id) owner
{
	return nil;
}

- (NSString *) itemIdentifier;
{
	return _itemIdentifier;
}

- (void) setItemIdentifier: (NSString *)anIdentifier
{
	ASSIGN(_itemIdentifier, anIdentifier);
}

- (void) checkConstraints: (NSMutableArray *)warnings
{

}

- (NSString *) warningWithMessage: (NSString *)msg
{
	return [[self description] stringByAppendingFormat: @" - %@", msg];
}

- (NSString *) displayName
{
	return [self name];
}

- (NSString *) typeDescription
{
	return @"Element";
}

- (NSArray *) properties
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];

	return [[super properties] arrayByAddingObjectsFromArray: 
		[[repo entityDescriptionForClass: [self class]] allPropertyDescriptionNames]]; 
}

@end
