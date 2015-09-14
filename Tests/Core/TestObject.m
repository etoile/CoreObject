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

- (void) testHashStabilityAcrossSetCurrentBranch
{
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
	COObject *object = [proot rootObject];
	const NSUInteger hash = [object hash];
	[ctx commit];
	
	COBranch *secondaryBranch = [[proot currentBranch] makeBranchWithLabel: @"secondaryBranch"];
	[proot setCurrentBranch: secondaryBranch];
	[ctx commit];
	
	UKIntsEqual(hash, [object hash]);
}

- (void) testIsEqualUsesPointerEquality
{
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
	[ctx commit];
	
	COObject *object = [proot rootObject];
	
	[self checkPersistentRootWithExistingAndNewContext: proot
											   inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testProot, COBranch *testBranch, BOOL isNewContext)
	 {
		 if (isNewContext)
		 {
			 UKObjectsNotEqual(object, [testProot rootObject]);
			 UKObjectsNotSame(object, [testProot rootObject]);
		 }
		 else
		 {
			 UKObjectsEqual(object, [testProot rootObject]);
			 UKObjectsSame(object, [testProot rootObject]);
		 }
	 }];
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

- (void) testTransientState
{
	ObjectWithTransientState *object =
		[ctx insertNewPersistentRootWithEntityName: @"ObjectWithTransientState"].rootObject;

	object.label = @"Whatever";
	object.derivedOrderedCollection = @[@"One", @"Two"];
	
	[ctx commit];
	
	[self checkPersistentRootWithExistingAndNewContext: object.persistentRoot
											  inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		ObjectWithTransientState *testObject = testPersistentRoot.rootObject;

		if (isNewContext)
		{
			UKNil(testObject.label);
			UKObjectsEqual(@[], testObject.orderedCollection);
		}
		else
		{
			UKStringsEqual(@"Whatever", testObject.label);
			UKObjectsEqual(A(@"One", @"Two"), testObject.orderedCollection);
		}
		UKObjectsEqual(testObject.orderedCollection, testObject.derivedOrderedCollection);
	}];
}

- (void) testExceptionOnTransientCollectionInvalidUpdate
{
	COPersistentRoot *persistentRoot =
		[ctx insertNewPersistentRootWithEntityName: @"ObjectWithTransientState"];
	
	// FIXME: Turn on to match COObject class documentation
	//UKRaisesException([persistentRoot.rootObject setValue: nil
	//                                          forProperty: @"orderedCollection"]);
}

- (void) testExceptionOnInvalidTransientCollectionAfterDeserialization
{
	ObjectWithTransientState *object =
		[ctx insertNewPersistentRootWithEntityName: @"ObjectWithTransientState"].rootObject;

	[object setValue: nil forStorageKey: @"orderedCollection"];
	
	UKRaisesException([object.objectGraphContext insertOrUpdateItems: @[object.storeItem]]);
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

/**
 * Simple test of -objectGraphContext, -branch, -persistentRoot, and -editingContext
 */
- (void) testPersistencyAttributes
{
	COObjectGraphContext *objectGraphContext = [COObjectGraphContext objectGraphContext];
	COObject *object = [[COObject alloc] initWithObjectGraphContext: objectGraphContext];
	
	UKObjectsSame(objectGraphContext, [object objectGraphContext]);
	UKNil([object branch]);
	UKNil([object persistentRoot]);
	UKNil([object editingContext]);
	
	COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithRootObject: object];
	COBranch *branch = [persistentRoot currentBranch];
	UKNotNil(persistentRoot);
	UKNotNil(branch);
	
	UKObjectsSame(objectGraphContext, [object objectGraphContext]);
	UKObjectsSame(branch, [object branch]);
	UKObjectsSame(persistentRoot, [object persistentRoot]);
	UKObjectsSame(ctx, [object editingContext]);
}

- (void) testEntityDescriptionImmutableAfterCOObjectCreation
{
	COObjectGraphContext *objectGraphContext = [COObjectGraphContext objectGraphContext];
	OutlineItem *object = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	
	ETEntityDescription *entityDesc = [object entityDescription];
	ETPropertyDescription *contentsDesc = [entityDesc propertyDescriptionForName: @"contents"];
	
	UKTrue([contentsDesc isOrdered]);
	UKRaisesException([contentsDesc setOrdered: NO]);
}

- (void) testDidChangeValueForWrongProperty
{
	COObjectGraphContext *objectGraphContext = [COObjectGraphContext objectGraphContext];
	OutlineItem *object = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	
	[object willChangeValueForProperty: @"label"];
	UKRaisesException([object didChangeValueForProperty: @"contents"]);
}

- (void) testUnpairedDidChangeValueForProperty
{
	COObjectGraphContext *objectGraphContext = [COObjectGraphContext objectGraphContext];
	OutlineItem *object = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	
	UKRaisesException([object didChangeValueForProperty: @"contents"]);
}

- (void) testEmptyDidChangeValueForProperty
{
	COObjectGraphContext *objectGraphContext = [COObjectGraphContext objectGraphContext];
	OutlineItem *object = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];
	
	[object willChangeValueForProperty: @"label"];
	UKDoesNotRaiseException([object didChangeValueForProperty: @"label"]);
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

#pragma mark - Test Insertion Hint

@interface OutlineItem_InsertObjectAtIndexHint_Mock : OutlineItem
@property (nonatomic, readwrite, strong) NSMutableArray *insertObjectArgumentsForCalls;
@end

@implementation OutlineItem_InsertObjectAtIndexHint_Mock

@synthesize insertObjectArgumentsForCalls;

-(void)insertObject:(id)object atIndex:(NSUInteger)index hint:(id)hint
{
	[super insertObject:object atIndex:index hint:hint];
	
	if (nil == insertObjectArgumentsForCalls)
		insertObjectArgumentsForCalls = [NSMutableArray array];

	[insertObjectArgumentsForCalls addObject: @{ @"object" : object,
												 @"index" : @(index),
												 @"hint" : hint ? hint : [NSNull null]}];
}

@end

@interface TestObjectInsertionHint : EditingContextTestCase <UKTest>
{
	COObjectGraphContext *objectGraphContext;
	OutlineItem_InsertObjectAtIndexHint_Mock *parent;
	OutlineItem *other;
}

@end

@implementation TestObjectInsertionHint

- (id)init
{
	SUPERINIT;
	objectGraphContext = [COObjectGraphContext objectGraphContext];

	parent = [[OutlineItem_InsertObjectAtIndexHint_Mock alloc]
				initWithObjectGraphContext: objectGraphContext];
	
	// N.B.: Not added to parent yet.
	other = [[OutlineItem alloc] initWithObjectGraphContext: objectGraphContext];

	return self;
}

- (void) testAddObject
{
	UKNil(parent.insertObjectArgumentsForCalls);
	[parent addObject: other];
	UKIntsEqual(1, [parent.insertObjectArgumentsForCalls count]);
	
	// Check the arguments that were passed to -insertObject:atIndex:hint:
	NSDictionary *args = parent.insertObjectArgumentsForCalls[0];
	UKObjectsSame(other, args[@"object"]);
	UKObjectsEqual(@(ETUndeterminedIndex), args[@"index"]);
	UKObjectsEqual([NSNull null], args[@"hint"]);
}

@end

