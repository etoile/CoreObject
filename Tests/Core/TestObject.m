/*
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  April 2013
    License:  MIT  (see COPYING)
 */

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

- (void) testEntityDescriptionMissingCOObjectParent
{
    ETEntityDescription *rootEntity = [ETEntityDescription descriptionWithName: @"RootEntity"];
	ETEntityDescription *emptyEntity = [ETEntityDescription descriptionWithName: @"EmptyEntity"];
	[emptyEntity setParent: (id)@"Anonymous.COObject"];

	[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: rootEntity];
	[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: emptyEntity];
	[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
	
	// Expected to fail because rootEntity does not declare COObject as its parent
	UKRaisesException([[COObject alloc] initWithEntityDescription: rootEntity
											   objectGraphContext: [COObjectGraphContext new]]);
	UKRaisesException([ctx insertNewPersistentRootWithEntityName: @"Anonymous.RootEntity"]);
	
	UKDoesNotRaiseException([[COObject alloc] initWithEntityDescription: emptyEntity
													 objectGraphContext: [COObjectGraphContext new]]);
	UKDoesNotRaiseException([ctx insertNewPersistentRootWithEntityName: @"Anonymous.EmptyEntity"]);
}

- (void) testInit
{
	UKRaisesException([[COObject alloc] init]);
}

- (void) testEquality
{
	COObject *object = [[ctx insertNewPersistentRootWithEntityName: @"COObject"] rootObject];
	COObject *otherObject = [[ctx insertNewPersistentRootWithEntityName: @"COObject"] rootObject];
	
	// FIXME: bookmark stuff is commented out because it fails serialization to an item graph
	
	//COBookmark *bookmark = [[ctx insertNewPersistentRootWithEntityName: @"COBookmark"] rootObject];

	UKObjectsEqual(object, object);
	//UKObjectsEqual(bookmark, bookmark);

	UKObjectsNotEqual(object, otherObject);
	UKObjectsNotEqual(otherObject, object);
	//UKObjectsNotEqual(object, bookmark);
	//UKObjectsNotEqual(bookmark, object);

	NSSet *objects = S(object, /*bookmark,*/ otherObject);

 	/* See also -[TestCollection testCollectionContainingCheapCopyAndOriginal] */
	UKObjectsEqual(objects, S(/*bookmark,*/ object, otherObject));
	UKTrue([objects containsObject: object]);
	//UKTrue([objects containsObject: bookmark]);
	UKTrue([objects containsObject: otherObject]);
}

- (void) testEqualityFromTransienceToPersistence
{
	COObjectGraphContext *objectGraphContext = [COObjectGraphContext objectGraphContext];
	COObject *object = [[COObject alloc] initWithObjectGraphContext: objectGraphContext];
	NSUInteger hash = [object hash];

	/* For testing the hash stability with -[NSSet containsObject:], we must 
	   insert the objects in the set before object becomes persistent */
	//COBookmark *bookmark = [[ctx insertNewPersistentRootWithEntityName: @"COBookmark"] rootObject];
	NSSet *objects = S(object/*, bookmark*/);

	UKObjectsEqual(object, object);
	
	[ctx insertNewPersistentRootWithRootObject: object];

	UKObjectsEqual(object, object);
	/* For objects in collections, -hash must never change otherwise 
	  -[NSSet containsObject:] reports wrong results (at least on Mac OS 10.7) */
	UKIntsEqual(hash, [object hash]);

	UKObjectsEqual(objects, S(/*bookmark,*/ object));
	UKTrue([objects containsObject: object]);
	//UKTrue([objects containsObject: bookmark]);
}

- (void) testDetailedDescription
{
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
	COObject *object = [proot rootObject];

	UKStringsEqual([object description], [object stringValue]);
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
	
	[self checkPersistentRootWithExistingAndNewContext: proot
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

- (void) testUsingZombieObjectRaisesException
{
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
	
	OutlineItem *obj2 = [[OutlineItem alloc] initWithObjectGraphContext: proot.objectGraphContext];
	[obj2 setLabel: @"test"];
	
	/* obj2 is removed since it's unreachable */
	[proot.objectGraphContext removeUnreachableObjects];
	
	UKRaisesException([obj2 setLabel: @"test2"]);
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
