/*
	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2010
	License: Modified BSD (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/EtoileFoundation.h>

#define SA(x) [NSSet setWithArray: x]

@interface TestModelDescriptionRepository : NSObject <UKTest>
{
	ETModelDescriptionRepository *repo;
	ETPackageDescription *anonymousPackage;
}

@end

@implementation TestModelDescriptionRepository

- (id) init
{
	SUPERINIT;
	repo = [[ETModelDescriptionRepository alloc] init];
	anonymousPackage = [repo anonymousPackageDescription];
	return self;
}

- (void) dealloc
{
	DESTROY(repo);
	[super dealloc];
}

- (void) testResolveObjectRefsWithMetaMetaModel
{
	ETEntityDescription *root = [repo descriptionForName: @"Object"];
	NSSet *primitiveDescClasses = 
		S([ETPrimitiveEntityDescription class], [ETCPrimitiveEntityDescription class]);
	
	/* For testing purpose, we just exclude the primitive entity classes but 
	   it is not the expected way to set up a repository (see +mainRepository). */		
	[repo collectEntityDescriptionsFromClass: [ETModelElementDescription class]
	                         excludedClasses: primitiveDescClasses
	                              resolveNow: YES];

	ETEntityDescription *element = [repo entityDescriptionForClass: [ETModelElementDescription class]];
	ETEntityDescription *entity = [repo entityDescriptionForClass: [ETEntityDescription class]];
	ETEntityDescription *property = [repo entityDescriptionForClass: [ETPropertyDescription class]];
	ETEntityDescription *package = [repo entityDescriptionForClass: [ETPackageDescription class]];

	UKNotNil(element);
	UKNotNil(entity);
	UKNotNil(property);
	UKNotNil(package);

	UKTrue([S(root, element, entity, property, package) isSubsetOfSet: SA([repo entityDescriptions])]);

	UKObjectsEqual(root, [repo entityDescriptionForClass: [NSObject class]]);
	UKObjectsEqual(element, [repo entityDescriptionForClass: [ETModelElementDescription class]]);
	UKObjectsEqual(entity, [repo entityDescriptionForClass: [ETEntityDescription class]]);
	UKObjectsEqual(property, [repo entityDescriptionForClass: [ETPropertyDescription class]]);
	UKObjectsEqual(package, [repo entityDescriptionForClass: [ETPackageDescription class]]);

	UKObjectsEqual(anonymousPackage, [element owner]);
	UKObjectsEqual(anonymousPackage, [entity owner]);
	UKObjectsEqual(anonymousPackage, [property owner]);
	UKObjectsEqual(anonymousPackage, [package owner]);

	UKObjectsEqual(root, [element parent]);
	UKObjectsEqual(element, [entity parent]);
	UKObjectsEqual(element, [property parent]);
	UKObjectsEqual(element, [package parent]);

	UKObjectsEqual(entity, [[property propertyDescriptionForName: @"type"] type]);

	UKObjectsEqual([entity propertyDescriptionForName: @"owner"], 
		[[package propertyDescriptionForName: @"entityDescriptions"] opposite]);
	UKObjectsEqual([package propertyDescriptionForName: @"entityDescriptions"], 
		[[entity propertyDescriptionForName: @"owner"] opposite]);

	UKObjectsEqual([property propertyDescriptionForName: @"owner"], 
		[[entity propertyDescriptionForName: @"propertyDescriptions"] opposite]);
	UKObjectsEqual([entity propertyDescriptionForName: @"propertyDescriptions"], 
		[[property propertyDescriptionForName: @"owner"] opposite]);

	UKObjectsEqual([property propertyDescriptionForName: @"package"], 
		[[package propertyDescriptionForName: @"propertyDescriptions"] opposite]);
	UKObjectsEqual([package propertyDescriptionForName: @"propertyDescriptions"], 
		[[property propertyDescriptionForName: @"package"] opposite]);

	NSMutableArray *warnings = [NSMutableArray array];
	[repo checkConstraints: warnings];
	UKTrue([warnings isEmpty]);
	if ([warnings isEmpty] == NO)
	{
		ETLog(@"Constraint Warnings: %@", warnings);
	}
	
}

@end
