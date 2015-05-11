/*
    Copyright (C) 2013 Quentin Mathe

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COObject.h"
#import "COObject+Private.h"

@interface TestObjectUpdateEntity : COObject
@end

@interface TestObjectUpdate : EditingContextTestCase
{
	id object;
	NSString *oldValue;
	NSString *newValue;
	id poster;
	int notificationCount;
}

@end

@interface TestIVarUpdate : TestObjectUpdate <UKTest>
@end

@interface TestVariableStorageUpdate : TestObjectUpdate <UKTest>
@end

@interface TestDirectVariableStorageUpdate : TestObjectUpdate <UKTest>
@end


@implementation TestObjectUpdateEntity
@end


@implementation TestObjectUpdate

- (NSString *) property
{
	return nil;
}

- (id) newValue
{
	return nil;
}

- (NSString *) entityName
{
	return @"TestObjectUpdateEntity";
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)anObject
                         change: (NSDictionary *)change
                        context: (void *)context
{
	if ([keyPath isEqual: [self property]])
	{
		oldValue = [change objectForKey: NSKeyValueChangeOldKey];
		newValue = [change objectForKey: NSKeyValueChangeNewKey];
		poster = anObject;
		notificationCount++;
	}
}

- (id)init
{
	SUPERINIT;
	object = [[ctx insertNewPersistentRootWithEntityName: [self entityName]] rootObject];
	[object addObserver: self
	         forKeyPath: [self property]
	            options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
	            context: NULL];
	ETAssert([self property] != nil);
	ETAssert([self newValue] != nil);
	return self;
}

- (void)dealloc
{
	[object removeObserver: self forKeyPath: [self property]];
}

- (void)validateKVOUpdate
{
	UKObjectsEqual([NSNull null], oldValue);
	UKObjectsEqual([self newValue], newValue);
	UKObjectsSame(object, poster);
	UKIntsEqual(1, notificationCount);
}

- (void)validateUpdate
{
	UKObjectsEqual([self newValue], [object valueForStorageKey: [self property]]);
	UKObjectsEqual([self newValue], [object valueForProperty: [self property]]);
	UKObjectsEqual([self newValue], [object valueForKey: [self property]]);

	[self validateKVOUpdate];
}

@end


// NOTE: A readwrite property bound a ivar must have a setter (synthesized or not)
@implementation TestIVarUpdate

- (NSString *) property
{
	return @"name";
}

- (id) newValue
{
	return @"Nobody";
}

- (void) testSetter
{
	[(COObject *)object setName: [self newValue]];

	[self validateUpdate];
}

- (void) testPVC
{
	[object setValue: [self newValue] forProperty: [self property]];
	
	[self validateUpdate];
}

- (void) testKVC
{
	[object setValue: [self newValue] forKey: [self property]];
	
	[self validateUpdate];
}

@end


@implementation TestVariableStorageUpdate

- (NSString *) property
{
	return @"label";
}

- (id) newValue
{
	return @"Tree";
}

- (NSString *) entityName
{
	return @"OutlineItem";
}

- (void) testSetter
{
	[object setLabel: [self newValue]];

	[self validateUpdate];
}

- (void) testPVC
{
	[object setValue: [self newValue] forProperty: [self property]];

	[self validateUpdate];
}

- (void) testKVC
{
	[object setValue: [self newValue] forKey: [self property]];
	
	[self validateUpdate];
}

@end


// NOTE: A readwrite property in the variable storage doesn't require a setter, 
// see -[COObject setValue:forUndefinedKey:].
@implementation TestDirectVariableStorageUpdate

- (NSString *) property
{
	return @"city";
}

- (id) newValue
{
	return @"Edmonton";
}

+ (void)addCityPropertyToEntity: (ETEntityDescription *)anEntity
{
	if (![[anEntity propertyDescriptionNames] containsObject: @"city"])
	{
		ETEntityDescription *stringType =
			[[ETModelDescriptionRepository mainRepository] descriptionForName: @"NSString"];
		ETPropertyDescription *propertyDesc =
			[ETPropertyDescription descriptionWithName: @"city" type: stringType];
		
		[anEntity addPropertyDescription: propertyDesc];
	}
}

- (id) init
{
	// N.B., We must add the 'city' property to COObject before registering
	// an observer for the 'city' key (done in [super init]), because we need
	// COObject to tell the KVO machinery that COObject will manually send
	// change notifications for the 'city' key (see +[COObject automaticallyNotifiesObserversForKey:]
	// and the [super didChangeValueForKey:] call in -[COObject didChangeValueForProperty]).
	//
	// If this was done after adding the KVO observer, KVO would do the dynamic
	// subclassing trick since it doesn't know that COObject will send manual KVO change
	// notifications for 'city', and we'd end up getting 2 notifications instead of 1 in -testKVC.
	
	// NOTE: The above comment no longer applies because you can't modify
	// an entity description after creating a COObject instance that uses it.
	
	[TestDirectVariableStorageUpdate addCityPropertyToEntity:
	 [[ETModelDescriptionRepository mainRepository] entityDescriptionForClass: [TestObjectUpdateEntity class]]];
		 
	SUPERINIT;
	return self;
}

- (void) testAbsentSetter
{
	UKFalse([object respondsToSelector: NSSelectorFromString(@"setCity:")]);
}

- (void) testPVC
{
	[object setValue: [self newValue] forProperty: [self property]];
	
	[self validateUpdate];
}

- (void) testKVC
{
	[object setValue: [self newValue] forKey: [self property]];
	
	[self validateUpdate];
}

@end
