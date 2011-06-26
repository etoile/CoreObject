#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "NSObject+Trait.h"
#import "ETCollection.h"
#import "Macros.h"
#import "EtoileCompatibility.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@interface AbstractTestCollection : NSObject <UKTest>
{
	NSMutableArray *collection;
}
@end

@interface TestCollectionTrait : AbstractTestCollection <ETCollection>
@end

@interface TestMutableCollectionTrait : AbstractTestCollection <ETCollection, ETCollectionMutation>
@end


@implementation AbstractTestCollection

- (id) init
{
	SUPERINIT;
	collection = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(collection);
	[super dealloc];
}

// TODO: We need the trait exclude operator to apply a trait and conserve 
// inherited methods.
/*
- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return collection;
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: collection];
}
*/

@end


@implementation TestCollectionTrait

+ (void) initialize
{
	[self applyTraitFromClass: [ETCollectionTrait class]];
}

- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return collection;
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: collection];
}

- (void) checkFixedCollectionCharacteristics
{
	UKTrue([self isOrdered]);
	UKObjectsSame(collection, [self content]);
	UKObjectsNotSame(collection, [self contentArray]);
	UKObjectsEqual(collection, [self contentArray]);
	UKObjectKindOf([self objectEnumerator], NSEnumerator);
}

- (void) testEmptyCollection
{
	[self checkFixedCollectionCharacteristics];
	UKIntsEqual(0, [self count]);
	UKTrue([self isEmpty]);
	UKFalse([self containsObject: @"Unknown"]);
	UKFalse([self containsCollection: S(@"Unknown")]);
}

- (void) testMutateCollection
{
	[collection addObject: @"Whatever"];

	[self checkFixedCollectionCharacteristics];
	UKIntsEqual(1, [self count]);
	UKFalse([self isEmpty]);
	UKTrue([self containsObject: @"Whatever"]);

	[collection addObject: @"Something"];

	[self checkFixedCollectionCharacteristics];
	UKIntsEqual(2, [self count]);
	UKFalse([self isEmpty]);
	UKTrue([self containsObject: @"Something"]);

	[collection removeAllObjects];
}

- (void) testContainsCollection
{
	NSArray *cities = A(@"Edmonton", @"Paris", @"Swansea");

	UKTrue([self containsCollection: self]);

	[collection addObjectsFromArray: cities];

	UKTrue([self containsCollection: self]);
	UKTrue([self containsCollection: [NSCountedSet setWithArray: cities]]);
	// FIXME:
	//UKTrue([self containsCollection: [NSDictionary dictionaryWithObjects: cities forKeys: A(@"A", @"B", "C")]]);

	[collection addObject: @"Nowhere"];

	UKTrue([self containsCollection: [NSSet setWithArray: cities]]);
	UKTrue([self containsCollection: A(@"Paris")]);
	UKFalse([self containsCollection: A(@"Swansea", @"London")]);

	[collection removeAllObjects];
}

@end


@implementation TestMutableCollectionTrait

+ (void) initialize
{
	[self applyTraitFromClass: [ETCollectionTrait class]];
	[self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return collection;
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: collection];
}

- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	if (index == ETUndeterminedIndex)
	{
		[collection addObject: object];
	}
	else
	{
		[collection insertObject: object atIndex: index];
	}
}

- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	if (index == ETUndeterminedIndex)
	{
		[collection removeObject: object];
	}
	else
	{
		[collection removeObjectAtIndex: index];
	}
}

- (id) init
{
	SUPERINIT;
	/* Insertion order matters */
	[collection addObject: @"Kyoto"];
	[collection addObject: @"Paris"];
	[collection addObject: @"London"];
	return self;
}

- (void) testInsert
{
	[self insertObject: @"Swansea" atIndex: 1];

	UKStringsEqual(@"Swansea", [collection objectAtIndex: 1]);
}

- (void) testAdd
{
	[self addObject: @"Anchorage"];

	UKStringsEqual(@"Anchorage", [collection lastObject]);
}

- (void) testRemove
{
	[self removeObjectAtIndex: 0];

	UKFalse([self containsObject: @"Kyoto"]);

	/* The index has priority over the object (first argument) */
	[self removeObject: @"London" atIndex: 0 hint: nil];

	UKFalse([collection containsObject: @"Paris"]);
	UKTrue([collection containsObject: @"London"]);

	[self removeObject: @"London"];

	UKFalse([collection containsObject: @"London"]);

}

@end

