/*
	Copyright (C) 2016 Quentin Mathe

	Date:  January 2016
	License:  MIT  (see COPYING)
 */

#import "Person.h"

@implementation Person

@dynamic role, summary, iconData, streetAddress, city, administrativeArea, postalCode, country, phoneNumber, website, emailAddress, stuff, students, teachers;

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [Person className]])
		return entity;

	ETPropertyDescription *role =
		[ETPropertyDescription descriptionWithName: @"role" typeName: @"NSString"];
	ETPropertyDescription *summary =
		[ETPropertyDescription descriptionWithName: @"summary" typeName: @"NSString"];
	ETPropertyDescription *age =
		[ETPropertyDescription descriptionWithName: @"age" typeName: @"NSInteger"];
	ETPropertyDescription *iconData =
		[ETPropertyDescription descriptionWithName: @"iconData" typeName: @"NSData"];
	ETPropertyDescription *streetAddress =
		[ETPropertyDescription descriptionWithName: @"streetAddress" typeName: @"NSString"];
	ETPropertyDescription *city =
		[ETPropertyDescription descriptionWithName: @"city" typeName: @"NSString"];
	ETPropertyDescription *administrativeArea =
		[ETPropertyDescription descriptionWithName: @"administrativeArea" typeName: @"NSString"];
	ETPropertyDescription *postalCode =
		[ETPropertyDescription descriptionWithName: @"postalCode" typeName: @"NSString"];
	ETPropertyDescription *country =
		[ETPropertyDescription descriptionWithName: @"country" typeName: @"NSString"];
	ETPropertyDescription *phoneNumber =
		[ETPropertyDescription descriptionWithName: @"phoneNumber" typeName: @"NSString"];
	ETPropertyDescription *website =
		[ETPropertyDescription descriptionWithName: @"website" typeName: @"NSURL"];
	[website setValueTransformerName: @"COURLToString"];
	[website setPersistentTypeName: @"NSString"];
	ETPropertyDescription *emailAddress =
		[ETPropertyDescription descriptionWithName: @"emailAddress" typeName: @"NSString"];
	ETPropertyDescription *stuff =
		[ETPropertyDescription descriptionWithName: @"stuff" typeName: @"COObject"];
	stuff.multivalued = YES;
	stuff.ordered = YES;
	ETPropertyDescription *students =
		[ETPropertyDescription descriptionWithName: @"students" typeName: @"Person"];
	students.oppositeName = @"Person.teachers";
	students.multivalued = YES;
	students.ordered = NO;
	ETPropertyDescription *teachers =
		[ETPropertyDescription descriptionWithName: @"teachers" typeName: @"Person"];
	teachers.oppositeName = @"Person.students";
	teachers.multivalued = YES;
	teachers.ordered = NO;
	teachers.derived = YES;

	NSArray *persistentProperties =
  		@[role, summary, age, iconData, streetAddress, city, administrativeArea, postalCode,
			country, phoneNumber, website, emailAddress, stuff, students];
	[[persistentProperties mappedCollection] setPersistent: YES];

	[entity setPropertyDescriptions:
	 	[@[teachers] arrayByAddingObjectsFromArray: persistentProperties]];

	return entity;
}

- (id)initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	if (self == nil)
		return nil;

	self.age = 0;
	return self;
}

- (NSInteger)age
{
	return [[self valueForVariableStorageKey: @"age"] integerValue];
}

- (void)setAge: (NSInteger)age
{
	[self willChangeValueForProperty: @"age"];
	[self setValue: @(age) forVariableStorageKey: @"age"];
	[self didChangeValueForProperty: @"age"];
}

@end
