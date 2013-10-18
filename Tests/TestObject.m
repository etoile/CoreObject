#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COObject.h"
#import "COBookmark.h"
#import "COSerialization.h"

#pragma GCC diagnostic ignored "-Wunused"

@interface COObject (COSerializationPrivate)
- (id)serializedValueForPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
- (void)setSerializedValue: (id)value forPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
@end

@interface COOverridenSetterBookmark : COBookmark
{
	@public
	BOOL setterInvoked;
	BOOL validated;
	BOOL serialized;
	BOOL deserialized;
}

@end

@interface TestObject : EditingContextTestCase <UKTest>
@end

@implementation TestObject

- (void) testEntityDescriptionMismatch
{
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
	ETEntityDescription *groupEntity = [repo entityDescriptionForClass: [COGroup class]];
	ETEntityDescription *libraryEntity = [repo entityDescriptionForClass: [COLibrary class]];
	ETEntityDescription *objectEntity = [repo entityDescriptionForClass: [COObject class]];

	UKRaisesException([[COContainer alloc] initWithEntityDescription: groupEntity
											      objectGraphContext: [COObjectGraphContext new]]);
	UKDoesNotRaiseException([[COContainer alloc] initWithEntityDescription: libraryEntity
											            objectGraphContext: [COObjectGraphContext new]]);
	UKDoesNotRaiseException([[COContainer alloc] initWithEntityDescription: objectEntity
											            objectGraphContext: [COObjectGraphContext new]]);
}

- (void) testCreationAndModificationDates
{
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
	COObject *object = [proot rootObject];

	UKNil([proot creationDate]);
	UKNil([proot modificationDate]);

	[object setName: @"Bing"];
	[ctx commit];

	CORevision *firstRev = [object revision];

	UKObjectsEqual([firstRev date], [proot creationDate]);
	UKObjectsEqual([firstRev date], [proot modificationDate]);

	[object setName: @"Bong"];
	[ctx commit];

	CORevision *lastRev = [object revision];
	UKObjectsNotEqual(lastRev, firstRev);
	
	[self testPersistentRootWithExistingAndNewContext: proot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 UKObjectsEqual([firstRev date], [testProot creationDate]);
		 UKObjectsEqual([lastRev date], [testProot modificationDate]);
	 }];
}

- (void) testKVCForSynthesizedSetterName
{
	COOverridenSetterBookmark *bookmark =
		[[ctx insertNewPersistentRootWithEntityName: @"COOverridenSetterBookmark"] rootObject];
	NSDate *date = [NSDate date];

	[bookmark setValue: date forProperty: @"lastVisitedDate"];

	UKObjectsEqual(date, [bookmark lastVisitedDate]);
	UKTrue(bookmark->setterInvoked);
}

- (void) testValidationForSynthesizedSetterName
{
	COOverridenSetterBookmark *bookmark =
		[[ctx insertNewPersistentRootWithEntityName: @"COOverridenSetterBookmark"] rootObject];
	NSDate *date = [NSDate date];
	NSArray *results = [bookmark validateValue: date forProperty: @"lastVisitedDate"];

	UKTrue([results isEmpty]);
	UKTrue(bookmark->validated);
}

- (void) testSerializationForSynthesizedSetterName
{
	COOverridenSetterBookmark *bookmark =
		[[ctx insertNewPersistentRootWithEntityName: @"COOverridenSetterBookmark"] rootObject];
	[bookmark setLastVisitedDate: [NSDate date]];
	ETPropertyDescription *propertyDesc =
		[[bookmark entityDescription] propertyDescriptionForName: @"lastVisitedDate"];

	NSString *dateString = [bookmark serializedValueForPropertyDescription: propertyDesc];

	UKObjectsEqual([[bookmark lastVisitedDate] stringValue], dateString);
	UKTrue(bookmark->serialized);
}

- (void) testDeserializationForSynthesizedSetterName
{
	COOverridenSetterBookmark *bookmark =
		[[ctx insertNewPersistentRootWithEntityName: @"COOverridenSetterBookmark"] rootObject];
	NSDate *date = [NSDate date];
	ETPropertyDescription *propertyDesc =
		[[bookmark entityDescription] propertyDescriptionForName: @"lastVisitedDate"];

	[bookmark setSerializedValue: date forPropertyDescription: propertyDesc];
	
	UKObjectsEqual(date, [bookmark lastVisitedDate]);
	UKTrue(bookmark->deserialized);
	UKTrue(bookmark->setterInvoked);
}

@end


@implementation COOverridenSetterBookmark

- (void) setLastVisitedDate: (NSDate *)lastVisitedDate
{
	setterInvoked = YES;
	[super setLastVisitedDate: lastVisitedDate];
}

- (id) validateLastVisitedDate: (id)aValue
{
	validated = YES;
	return [ETValidationResult validResult: aValue];
}

- (id) serializedLastVisitedDate
{
	serialized = YES;
	return [[self lastVisitedDate] stringValue];
}

- (void) setSerializedLastVisitedDate: (id)aValue
{
	deserialized = YES;
	[self setLastVisitedDate: aValue];
}

@end
