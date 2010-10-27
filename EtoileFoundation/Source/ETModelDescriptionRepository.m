/*
	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2010
	License:  Modified BSD (see COPYING)
 */

#import "ETModelDescriptionRepository.h"
#import "ETClassMirror.h"
#import "ETCollection.h"
#import "ETCollection+HOM.h"
#import "ETEntityDescription.h"
#import "ETPackageDescription.h"
#import "ETPropertyDescription.h"
#import "ETReflection.h"
#import "NSObject+Etoile.h"
#import "NSObject+Model.h"
#import "Macros.h"
#import "EtoileCompatibility.h"


@implementation ETModelDescriptionRepository

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *selfDesc = [self newBasicEntityDescription];

	if ([[selfDesc name] isEqual: [ETModelDescriptionRepository className]] == NO) 
		return selfDesc;

	// TODO: Add property descriptions...

	return selfDesc;
}

- (void) addUnresolvedEntityDescriptionForClass: (Class)aClass
{
	ETEntityDescription *entityDesc = [aClass newEntityDescription];
	[self addUnresolvedDescription: entityDesc];
	[self setEntityDescription: entityDesc forClass: aClass];
}

- (void) collectEntityDescriptionsFromClass: (Class)aClass 
                            excludedClasses: (NSSet *)excludedClasses 
                                 resolveNow: (BOOL)resolve
{
	[self addUnresolvedEntityDescriptionForClass: aClass];
	FOREACH([[ETReflection reflectClass: aClass] allSubclassMirrors], mirror, ETClassMirror *)
	{
		if ([excludedClasses containsObject: [mirror representedClass]])
			continue;

		[self addUnresolvedEntityDescriptionForClass: [mirror representedClass]];
	}
	if (resolve)
	{
		[self resolveNamedObjectReferences];
	}
}

static ETModelDescriptionRepository *mainRepo = nil;

+ (id) mainRepository
{
	if (nil == mainRepo)
	{
		mainRepo = [[self alloc] init];
		[mainRepo collectEntityDescriptionsFromClass: [ETModelElementDescription class] 
		                             excludedClasses: nil
		                                  resolveNow: YES];
	}
	return mainRepo;
}

- (NSArray *) newObjectPrimitives
{
	ETEntityDescription *objectDesc = [NSObject newEntityDescription];
	ETEntityDescription *stringDesc = [NSString newEntityDescription];
	ETEntityDescription *dateDesc = [NSDate newEntityDescription];
	/* We include NSValue because it is NSNumber superclass */
	ETEntityDescription *valueDesc = [NSValue newEntityDescription];
	ETEntityDescription *numberDesc = [NSNumber newEntityDescription];
	ETEntityDescription *booleanDesc = [NSNumber newEntityDescription];
	[booleanDesc setName: @"Boolean"];
	NSArray *objCPrimitives = A(objectDesc, stringDesc, dateDesc, valueDesc, 
		numberDesc, booleanDesc);

	FOREACHI(objCPrimitives, desc)
	{
		object_setClass(desc, [ETPrimitiveEntityDescription class]);	
	}

	return objCPrimitives;
}

- (NSArray *) newCPrimitives
{
	return A([ETCPrimitiveEntityDescription descriptionWithName: @"BOOL"],
		[ETCPrimitiveEntityDescription descriptionWithName: @"NSInteger"],
		[ETCPrimitiveEntityDescription descriptionWithName: @"NSUInteger"],
		[ETCPrimitiveEntityDescription descriptionWithName: @"float"]);
}

- (void) setUpWithCPrimitives: (NSArray *)cPrimitives 
             objectPrimitives: (NSArray *)objcPrimitives
{
	NSArray *primitives = [objcPrimitives arrayByAddingObjectsFromArray: cPrimitives];

	FOREACH(primitives, cDesc, ETEntityDescription *)
	{
		[self addUnresolvedDescription: cDesc];
	}
	FOREACH(objcPrimitives, objcDesc, ETEntityDescription *)
	{
		NSString *className = [objcDesc name];
		Class class = NSClassFromString(className);
		NSString *typePrefix = (Nil != class ? [class typePrefix] : (NSString *)@"");

		if (Nil != class)
		{
			[self setEntityDescription: objcDesc forClass: class];
		}

		/* FM3 names are Object, String, Date, Number and Boolean */
		int prefixEnd = [className rangeOfString: typePrefix
		                                 options: NSAnchoredSearch].length;
		NSString *fm3Name = [className substringFromIndex: prefixEnd];

		[_descriptionsByName setObject: objcDesc forKey: fm3Name];
	}
	[self resolveNamedObjectReferences];
}

static NSString *anonymousPackageName = @"Anonymous";

- (id) init
{
	SUPERINIT;
	_unresolvedDescriptions = [[NSMutableSet alloc] init];
	_descriptionsByName = [[NSMutableDictionary alloc] init];
	_entityDescriptionsByClass = [[NSMapTable alloc] init];
	[self addDescription: [ETPackageDescription descriptionWithName: anonymousPackageName]];
	[self setUpWithCPrimitives: [self newCPrimitives] 
	          objectPrimitives: [self newObjectPrimitives]];

	ETAssert([[ETEntityDescription rootEntityDescriptionName] isEqual:
		[[self descriptionForName: @"Object"] name]]);

	return self;
}

- (void) dealloc
{
	DESTROY(_unresolvedDescriptions);
	DESTROY(_descriptionsByName);
	DESTROY(_entityDescriptionsByClass);
	[super dealloc];
}

- (ETPackageDescription *) anonymousPackageDescription
{
	return [self descriptionForName: anonymousPackageName];
}

- (void) addDescriptions: (NSArray *)descriptions
{
	FOREACH(descriptions, desc, ETModelElementDescription *)
	{
		[self addDescription: desc];
	}
}

- (void) addDescription: (ETModelElementDescription *)aDescription
{
	if ([aDescription isEntityDescription] && [aDescription owner] == nil)
	{
		[[self anonymousPackageDescription] addEntityDescription: (ETEntityDescription *)aDescription];
	}
	[_descriptionsByName setObject: aDescription forKey: [aDescription fullName]];
}

- (void) removeDescription: (ETModelElementDescription *)aDescription
{
	[_descriptionsByName removeObjectForKey: [aDescription fullName]];
	ETAssert([[_descriptionsByName allKeysForObject: aDescription] isEmpty]);
}

- (NSArray *) packageDescriptions
{
	NSMutableArray *descriptions = [NSMutableArray arrayWithArray: [_descriptionsByName allValues]];
	[[descriptions filter] isPackageDescription];
	return descriptions;
}

- (NSArray *) entityDescriptions
{
	NSMutableArray *descriptions = [NSMutableArray arrayWithArray: [_descriptionsByName allValues]];
	[[descriptions filter] isEntityDescription];
	return descriptions;
}

- (NSArray *) propertyDescriptions
{
	NSMutableArray *descriptions = [NSMutableArray arrayWithArray: [_descriptionsByName allValues]];
	[[descriptions filter] isPropertyDescription];
	return descriptions;
}

- (NSArray *) allDescriptions
{
	return AUTORELEASE([[_descriptionsByName allValues] copy]);
}

- (id) descriptionForName: (NSString *)aFullName
{
	return [_descriptionsByName objectForKey: aFullName];
}

/* Binding Descriptions to Class Instances and Prototypes */

- (ETEntityDescription *) entityDescriptionForClass: (Class)aClass
{
	return [_entityDescriptionsByClass objectForKey: aClass];
}

- (void) setEntityDescription: (ETEntityDescription *)anEntityDescription
                     forClass: (Class)aClass
{
	if ([_descriptionsByName objectForKey: [anEntityDescription fullName]] == nil
	 && [_unresolvedDescriptions containsObject: anEntityDescription] == NO)
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"The entity description must have been previously "
					         "added to the repository"];
	}
	[_entityDescriptionsByClass setObject: anEntityDescription forKey: aClass];
}

- (void) addUnresolvedDescription: (ETModelElementDescription *)aDescription
{
	[_unresolvedDescriptions addObject: aDescription];
}

/* 'isPackageRef' prevents to wrongly look up a package as an entity (with the 
same name). */
- (void) resolveProperty: (NSString *)aProperty
          forDescription: (ETModelElementDescription *)desc
            isPackageRef: (BOOL)isPackageRef
{
	id value = [desc valueForKey: aProperty];

	if ([value isString] == NO) return;

	id realValue = [self descriptionForName: (NSString *)value];
	BOOL lookUpInAnonymousPackage = (nil == realValue && NO == isPackageRef);

	if (lookUpInAnonymousPackage)
	{
		value = [anonymousPackageName stringByAppendingFormat: @".%@", value];
		realValue = [self descriptionForName: (NSString *)value];
	}
	if (nil != realValue) 
	{
		[desc setValue: realValue forKey: aProperty];
	}
}

- (NSSet *) resolveAndAddEntityDescriptions: (NSSet *)unresolvedEntityDescs
{
	NSMutableSet *propertyDescs = [NSMutableSet set];

	FOREACH(unresolvedEntityDescs, desc, ETEntityDescription *)
	{
		[self resolveProperty: @"owner" forDescription: desc isPackageRef: YES];
		[propertyDescs addObjectsFromArray: [desc propertyDescriptions]];
		[self addDescription: desc];
	}

	FOREACH(unresolvedEntityDescs, desc2, ETEntityDescription *)
	{
		[self resolveProperty: @"parent" forDescription: desc2 isPackageRef: NO];
	}

	return propertyDescs;
}

- (void) resolveAndAddPropertyDescriptions:(NSMutableSet *)unresolvedPropertyDescs
{
	FOREACH(unresolvedPropertyDescs, desc, ETPropertyDescription *)
	{
		[self resolveProperty: @"type" forDescription: desc isPackageRef: NO];
		[self resolveProperty: @"owner" forDescription: desc isPackageRef: NO];
		/* A package is set when the property is an entity extension */
		[self resolveProperty: @"package" forDescription: desc isPackageRef: YES];
		 /* For property extension */
		[self addDescription: desc];
	}

	FOREACH(unresolvedPropertyDescs, desc2, ETPropertyDescription *)
	{
		[self resolveProperty: @"opposite" forDescription: desc2 isPackageRef: NO];
	}
}

- (void) resolveNamedObjectReferences
{
	NSMutableSet *unresolvedPackageDescs = [NSMutableSet setWithSet: _unresolvedDescriptions];
	NSMutableSet *unresolvedEntityDescs = [NSMutableSet setWithSet: _unresolvedDescriptions];
	NSMutableSet *unresolvedPropertyDescs = [NSMutableSet setWithSet: _unresolvedDescriptions];

	[[unresolvedPackageDescs filter] isPackageDescription];
	[[unresolvedEntityDescs filter] isEntityDescription];
	[[unresolvedPropertyDescs filter] isPropertyDescription];

	[self addDescriptions: [unresolvedPackageDescs allObjects]];
	NSSet *collectedPropertyDescs = 
		[self resolveAndAddEntityDescriptions: unresolvedEntityDescs];
	[unresolvedPropertyDescs unionSet: collectedPropertyDescs];
	[self resolveAndAddPropertyDescriptions: unresolvedPropertyDescs];
}

- (void) checkConstraints: (NSMutableArray *)warnings
{
	FOREACH([self packageDescriptions], packageDesc, ETPackageDescription *)
	{
		[packageDesc checkConstraints: warnings];
	}
}

/* Collection Protocol */

/** Returns NO */
- (BOOL) isOrdered
{
	return NO;
}

/** Returns YES when no package descriptions is registered, otherwise returns NO.

By default, returns NO since an anonymous package descriptions is registered in 
any new repository. */
- (BOOL) isEmpty
{
	return ([[self packageDescriptions] count] == 0);
}

/** Returns a dictionary containing all the registered descriptions keyed by 
full name.

The returned dictionary contains descriptions other than package descriptions. 
You must assume that <code>[[self content] count] != [[self contentArray] count]</code>. */
- (id) content
{
	return _descriptionsByName;
}

/** Returns the registered package descriptions. See -packageDescriptions. */
- (NSArray *) contentArray
{
	return [self packageDescriptions];
}

/** Returns the number of registered package descriptions. */
- (NSUInteger) count
{
	return [[self packageDescriptions] count];
}

/** Returns an object to enumerate the registered package descriptions. */
- (id) objectEnumerator
{
	return [[self packageDescriptions] objectEnumerator];
}

@end
