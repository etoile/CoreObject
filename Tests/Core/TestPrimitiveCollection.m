/*
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  April 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestMutableArray : NSObject <UKTest>
{
	COMutableArray *array;
	id alive1;
	id alive2;
	id alive3;
	id dead1;
	id dead2;
	id dead3;
	
}

@end

@implementation TestMutableArray

- (id)init
{
	SUPERINIT;
	array = [COMutableArray new];
	[array beginMutation];
	alive1 = @"alive1";
	alive2 = @"alive2";
	alive3 = @"alive3";
	dead1 = [COPath pathWithPersistentRoot: [ETUUID UUID]];
	dead2 = [COPath pathWithPersistentRoot: [ETUUID UUID]];
	dead3 = [COPath pathWithPersistentRoot: [ETUUID UUID]];
	return self;
}

- (void)testEmptyCollection
{
	UKIntsEqual(0, array.count);
	UKFalse([array containsObject: @"something"]);
}

#pragma mark - Backing Operations

- (void)testAliveReferenceAddition
{
	[array addReference: alive1];
	
	UKTrue(array.deadIndexes.isEmpty);
	UKTrue(array.deadReferences.isEmpty);
	UKIntsEqual(1, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
}

- (void)testDeadReferenceAddition
{
	[array addReference: dead1];
	
	UKObjectsEqual(INDEXSET(0), array.deadIndexes);
	UKObjectsEqual(A(dead1), array.deadReferences);
	UKObjectsEqual(A(dead1), array.allReferences);
	UKIntsEqual(0, array.count);
	UKFalse([array containsObject: dead1]);
	UKRaisesException([array objectAtIndex: 0]);
}

- (void)testDeadBeforeAliveReferenceAddition
{
	[array addReference: dead1];
	[array addReference: alive1];

	UKObjectsEqual(INDEXSET(0), array.deadIndexes);
	UKObjectsEqual(A(dead1), array.deadReferences);
	UKObjectsEqual(A(dead1, alive1), array.allReferences);
	UKIntsEqual(1, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKRaisesException([array objectAtIndex: 1]);
}

- (void)testDeadAfterAliveReferenceAddition
{
	[array addReference: alive1];
	[array addReference: dead1];
	
	UKObjectsEqual(INDEXSET(1), array.deadIndexes);
	UKObjectsEqual(A(dead1), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1), array.allReferences);
	UKIntsEqual(1, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKRaisesException([array objectAtIndex: 1]);
}

- (void)testDeadAndAliveMixedReferenceAddition
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: dead2];
	[array addReference: alive2];
	[array addReference: dead3];

	UKObjectsEqual(INDEXSET(1, 2, 4), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2, dead3), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, dead2, alive2, dead3), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testDeadReferenceReplacement
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];

	[array replaceReferenceAtIndex: 3 withReference: dead3];

	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead3), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive2, dead3), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testAliveReferenceReplacement
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array replaceReferenceAtIndex: 2 withReference: alive3];
	
	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive3, dead2), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive3, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testDeadReferenceToAliveReplacementAtStart
{
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array replaceReferenceAtIndex: 0 withReference: alive1];

	UKObjectsEqual(INDEXSET(2), array.deadIndexes);
	UKObjectsEqual(A(dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, alive2, dead2), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testDeadReferenceToAliveReplacementInMiddle
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive3];
	[array addReference: dead2];
	
	[array replaceReferenceAtIndex: 1 withReference: alive2];
	
	UKObjectsEqual(INDEXSET(3), array.deadIndexes);
	UKObjectsEqual(A(dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, alive2, alive3, dead2), array.allReferences);
	UKIntsEqual(3, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKObjectsEqual(alive3, [array objectAtIndex: 2]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testDeadReferenceToAliveReplacementAtEnd
{
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array replaceReferenceAtIndex: 2 withReference: alive3];
	
	UKObjectsEqual(INDEXSET(0), array.deadIndexes);
	UKObjectsEqual(A(dead1), array.deadReferences);
	UKObjectsEqual(A(dead1, alive2, alive3), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive2, [array objectAtIndex: 0]);
	UKObjectsEqual(alive3, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testAliveReferenceToDeadReplacementAtStart
{
	[array addReference: alive1];
	[array addReference: dead2];
	[array addReference: alive2];
	
	[array replaceReferenceAtIndex: 0 withReference: dead1];
	
	UKObjectsEqual(INDEXSET(0, 1), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(dead1, dead2, alive2), array.allReferences);
	UKIntsEqual(1, array.count);
	UKObjectsEqual(alive2, [array objectAtIndex: 0]);
	UKRaisesException([array objectAtIndex: 1]);
}

- (void)testAliveReferenceToDeadReplacementInMiddle
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead3];
	
	[array replaceReferenceAtIndex: 2 withReference: dead2];
	
	UKObjectsEqual(INDEXSET(1, 2, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2, dead3), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, dead2, dead3), array.allReferences);
	UKIntsEqual(1, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKRaisesException([array objectAtIndex: 1]);
}

- (void)testAliveReferenceToDeadReplacementAtEnd
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	
	[array replaceReferenceAtIndex: 2 withReference: dead2];
	
	UKObjectsEqual(INDEXSET(1, 2), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, dead2), array.allReferences);
	UKIntsEqual(1, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKRaisesException([array objectAtIndex: 1]);
}

#pragma mark - Alive Objects Primitive Operations

- (void)testAddObjectRejectsReference
{
	COPath *p = [COPath pathWithPersistentRoot: [ETUUID UUID]];
	UKRaisesException([array addObject: p]);
}

- (void)testFirstObjectInsertion
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array insertObject: alive3 atIndex: 0];
	
	UKObjectsEqual(INDEXSET(2, 4), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive3, alive1, dead1, alive2, dead2), array.allReferences);
	UKIntsEqual(3, array.count);
	UKObjectsEqual(alive3, [array objectAtIndex: 0]);
	UKObjectsEqual(alive1, [array objectAtIndex: 1]);
	UKObjectsEqual(alive2, [array objectAtIndex: 2]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testMiddleObjectInsertion
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array insertObject: alive3 atIndex: 1];
	
	UKObjectsEqual(INDEXSET(1, 4), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive3, alive2, dead2), array.allReferences);
	UKIntsEqual(3, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive3, [array objectAtIndex: 1]);
	UKObjectsEqual(alive2, [array objectAtIndex: 2]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testLastObjectInsertion
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array insertObject: alive3 atIndex: 2];
	
	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive2, dead2, alive3), array.allReferences);
	UKIntsEqual(3, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKObjectsEqual(alive3, [array objectAtIndex: 2]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testFirstObjectRemoval
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	[array addReference: alive3];
	
	[array removeObjectAtIndex: 0];
	
	UKObjectsEqual(INDEXSET(0, 2), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(dead1, alive2, dead2, alive3), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive2, [array objectAtIndex: 0]);
	UKObjectsEqual(alive3, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testMiddleObjectRemoval
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	[array addReference: alive3];

	[array removeObjectAtIndex: 1];
	
	UKObjectsEqual(INDEXSET(1, 2), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, dead2, alive3), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive3, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testLastObjectRemoval
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	[array addReference: alive3];

	[array removeObjectAtIndex: 2];
	
	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive2, dead2), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testFirstObjectReplacement
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array replaceObjectAtIndex: 0 withObject: alive3];
	
	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive3, dead1, alive2, dead2), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive3, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

- (void)testLastObjectReplacement
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array replaceObjectAtIndex: 1 withObject: alive3];
	
	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive3, dead2), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive3, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 2]);
}

#pragma mark - Alive Objects Additional Operations

/**
 * -addObject: must call -insertObject:atIndex: with a valid index when the
 * collection is empty.
 */
- (void)testFirstObjectAddition
{
	[array addObject: alive3];

	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	// Tests identical to -testFirstObjectInsertion
	UKObjectsEqual(INDEXSET(2, 4), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive3, alive1, dead1, alive2, dead2), array.allReferences);
	UKIntsEqual(3, array.count);
	UKObjectsEqual(alive3, [array objectAtIndex: 0]);
	UKObjectsEqual(alive1, [array objectAtIndex: 1]);
	UKObjectsEqual(alive2, [array objectAtIndex: 2]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testLastObjectAddition
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	
	[array addObject: alive3];

	// Tests identical to -testLastObjectInsertion
	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive2, dead2, alive3), array.allReferences);
	UKIntsEqual(3, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKObjectsEqual(alive3, [array objectAtIndex: 2]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testRemoveLastObject
{
	[array addReference: alive1];
	[array addReference: dead1];
	[array addReference: alive2];
	[array addReference: dead2];
	[array addReference: alive3];
	
	[array removeLastObject];
	
	// Tests identical to -testLastObjectRemoval
	UKObjectsEqual(INDEXSET(1, 3), array.deadIndexes);
	UKObjectsEqual(A(dead1, dead2), array.deadReferences);
	UKObjectsEqual(A(alive1, dead1, alive2, dead2), array.allReferences);
	UKIntsEqual(2, array.count);
	UKObjectsEqual(alive1, [array objectAtIndex: 0]);
	UKObjectsEqual(alive2, [array objectAtIndex: 1]);
	UKRaisesException([array objectAtIndex: 3]);
}

- (void)testRemoveLastObjectWhenEmpty
{
	UKDoesNotRaiseException([array removeLastObject]);
}

- (void)testTemporaryMutation
{
	UKTrue(array.isMutable); // We called -beginMutation in -init
	UKDoesNotRaiseException([array addObject: @"a"]);
	[array endMutation];
	
	UKFalse(array.isMutable);
	UKRaisesException([array addObject: @"a"]);
	
	// Now test two -beginMutation calls
	[array beginMutation];
	[array beginMutation];
	
	// Making a copy should preserve the "level" of -beginMutation calls
	COMutableArray *arrayCopy = [array copy];
	UKTrue(arrayCopy.isMutable);
	UKDoesNotRaiseException([arrayCopy addObject: @"a"]);
	
	[arrayCopy endMutation];
	
	UKTrue(arrayCopy.isMutable);
	UKDoesNotRaiseException([arrayCopy addObject: @"a"]);
	
	[arrayCopy endMutation];
	
	UKFalse(arrayCopy.isMutable);
	UKRaisesException([arrayCopy addObject: @"a"]);
}

- (void)testFastEnumeration
{
	NSMutableArray *enumeratedObjects = [NSMutableArray new];

	[array addReference: dead1];
	[array addReference: alive1];
	
	for (NSString *alive in array)
	{
		[enumeratedObjects addObject: alive];
	}
	
	UKObjectsEqual(@[alive1], enumeratedObjects);
}

@end

#pragma mark - TestMutableSet

@interface TestMutableSet : NSObject <UKTest>
{
	COMutableSet *set;
	id alive1;
	id alive2;
	id dead1;
	id dead2;
}

@end

@implementation TestMutableSet

- (id)init
{
	SUPERINIT;
	set = [COMutableSet new];
	[set beginMutation];
	alive1 = @"alive1";
	alive2 = @"alive2";
	dead1 = [COPath pathWithPersistentRoot: [ETUUID UUID]];
	dead2 = [COPath pathWithPersistentRoot: [ETUUID UUID]];
	return self;
}

- (void)testEmptyCollection
{
	UKIntsEqual(0, set.count);
	UKIntsEqual(0, set.allReferences.count);
	UKFalse([set containsObject: @"something"]);
}

#pragma mark - Backing Operations

- (void)testAliveReferenceAddition
{
	[set addReference: alive1];
	
	UKTrue(set.deadReferences.isEmpty);
	UKIntsEqual(1, set.count);
	UKObjectsEqual(alive1, [set anyObject]);
	UKObjectsEqual(S(alive1), set.allReferences);
}

- (void)testDeadReferenceAddition
{
	[set addReference: dead1];
	
	UKObjectsEqual(S(dead1), set.allReferences);
	UKObjectsEqual(S(dead1), set.deadReferences);
	UKObjectsEqual(S(), set);
	UKIntsEqual(0, set.count);
	UKFalse([set containsObject: dead1]);
	UKNil([set member: dead1]);
}

- (void)testDeadBeforeAliveReferenceAddition
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	UKObjectsEqual(S(dead1, alive1), set.allReferences);
	UKObjectsEqual(S(dead1), set.deadReferences);
	UKObjectsEqual(S(alive1), set);
	UKIntsEqual(1, set.count);
	UKFalse([set containsObject: dead1]);
	UKTrue([set containsObject: alive1]);
}

- (void)testDeadReferenceReplacement
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	// replace dead1 with dead2
	[set removeReference: dead1];
	[set addReference: dead2];
	
	UKObjectsEqual(S(dead2, alive1), set.allReferences);
	UKObjectsEqual(S(dead2), set.deadReferences);
	UKObjectsEqual(S(alive1), set);
	UKIntsEqual(1, set.count);
}

- (void)testAliveReferenceReplacement
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	// replace alive1 with alive2
	[set removeReference: alive1];
	[set addReference: alive2];
	
	UKObjectsEqual(S(alive2, dead1), set.allReferences);
	UKObjectsEqual(S(dead1), set.deadReferences);
	UKObjectsEqual(S(alive2), set);
	UKIntsEqual(1, set.count);
}

- (void)testDeadReferenceToAliveReplacement
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	// replace dead1 with alive2
	[set removeReference: dead1];
	[set addReference: alive2];
	
	UKObjectsEqual(S(alive1, alive2), set.allReferences);
	UKObjectsEqual(S(), set.deadReferences);
	UKObjectsEqual(S(alive1, alive2), set);
	UKIntsEqual(2, set.count);
}

- (void)testAliveReferenceToDeadReplacement
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	// replace alive1 with dead2
	[set removeReference: alive1];
	[set addReference: dead2];
	
	UKObjectsEqual(S(dead1, dead2), set.allReferences);
	UKObjectsEqual(S(dead1, dead2), set.deadReferences);
	UKObjectsEqual(S(), set);
	UKIntsEqual(0, set.count);
}

#pragma mark - Alive Objects Primitive Operations

- (void)testAddObjectRejectsReference
{
	COPath *p = [COPath pathWithPersistentRoot: [ETUUID UUID]];
	UKRaisesException([set addObject: p]);
}

- (void)testObjectInsertion
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	[set addObject: alive2];
	
	UKObjectsEqual(S(dead1, alive1, alive2), set.allReferences);
	UKObjectsEqual(S(dead1), set.deadReferences);
	UKObjectsEqual(S(alive1, alive2), set);
	UKIntsEqual(2, set.count);
}

- (void)testObjectRemoval
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	[set removeObject: alive1];
	
	UKObjectsEqual(S(dead1), set.allReferences);
	UKObjectsEqual(S(dead1), set.deadReferences);
	UKObjectsEqual(S(), set);
	UKIntsEqual(0, set.count);
}

- (void) testRemoveAllObjects
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	[set removeAllObjects];
	
	UKObjectsEqual(S(dead1), set.allReferences);
	UKObjectsEqual(S(dead1), set.deadReferences);
	UKObjectsEqual(S(), set);
	UKIntsEqual(0, set.count);
}

- (void) testSetSet
{
	[set addReference: dead1];
	[set addReference: alive1];
	
	[set setSet: [NSSet set]];
	
	UKObjectsEqual(S(dead1), set.allReferences);
	UKObjectsEqual(S(dead1), set.deadReferences);
	UKObjectsEqual(S(), set);
	UKIntsEqual(0, set.count);
}

- (void)testTemporaryMutation
{
	UKTrue(set.isMutable); // We called -beginMutation in -init
	UKDoesNotRaiseException([set addObject: @"a"]);
	[set endMutation];
	
	UKFalse(set.isMutable);
	UKRaisesException([set addObject: @"a"]);
	
	// Now test two -beginMutation calls
	[set beginMutation];
	[set beginMutation];
	
	// Making a copy should preserve the "level" of -beginMutation calls
	COMutableArray *setCopy = [set copy];
	UKTrue(setCopy.isMutable);
	UKDoesNotRaiseException([setCopy addObject: @"a"]);
	
	[setCopy endMutation];
	
	UKTrue(setCopy.isMutable);
	UKDoesNotRaiseException([setCopy addObject: @"a"]);
	
	[setCopy endMutation];
	
	UKFalse(setCopy.isMutable);
	UKRaisesException([setCopy addObject: @"a"]);
}

- (void)testFastEnumeration
{
	NSMutableSet *enumeratedObjects = [NSMutableSet new];

	[set addReference: dead1];
	[set addReference: alive1];
	
	for (NSString *alive in set)
	{
		[enumeratedObjects addObject: alive];
	}
	
	UKObjectsEqual(S(alive1), enumeratedObjects);
}

@end


#pragma mark - TestUnsafeRetainedMutableArray

@interface TestUnsafeRetainedMutableArray : NSObject <UKTest>
{
	COUnsafeRetainedMutableArray *array;
}

@end

@implementation TestUnsafeRetainedMutableArray

- (id)init
{
	SUPERINIT;
	array = [COUnsafeRetainedMutableArray new];
	[array beginMutation];
	return self;
}

- (void) testDoesNotRetain
{
	__weak id weakReference = nil;
	
	@autoreleasepool {
		NSObject *content = [NSObject new];
		weakReference = content;
		[array addObject: content];
		UKObjectsSame(weakReference, array[0]);
		UKNotNil(weakReference);
	}
	UKNil(weakReference);
}

- (void) testDoesRetainCOPath
{
	__weak COPath *weakReference = nil;
	
	@autoreleasepool {
		COPath *p = [COPath pathWithPersistentRoot: [ETUUID UUID]];
		weakReference = p;
		[array addReference: p];
		UKNotNil(weakReference);
	}

	// Going out of scope should not deallocate it
	@autoreleasepool {
		UKNotNil(weakReference);
	}
	
	// Removing it from the collection should deallocate it
	@autoreleasepool {
		[array replaceReferenceAtIndex: 0 withReference: @"replacement object"];
	}
	UKNil(weakReference);
}

- (void) testDisallowsDuplicates
{
	[array addObject: @"a"];
	[array addObject: @"b"];
	[array addObject: [NSString stringWithFormat: @"a"]];
	UKObjectsEqual(A(@"a", @"b"), array);
}

- (void) testAllowsReinsertion
{
	[array addObject: @"a"];
	UKObjectsEqual(A(@"a"), array);
	[array removeObject: @"a"];
	UKObjectsEqual(A(), array);
	[array addObject: @"a"];
	UKObjectsEqual(A(@"a"), array);
}

- (void)testMultipleBrokenPaths
{
	@autoreleasepool {
		COPath *br1 = [COPath brokenPath];
		COPath *br2 = [COPath brokenPath];
		[array addReference: br1];
		[array addReference: br2];
	}
	// Ensure the array retained both
	UKTrue([[array referenceAtIndex: 0] isBroken]);
	UKTrue([[array referenceAtIndex: 1] isBroken]);
}

- (void)testMultipleBrokenPathsReplacement
{
	[array addObject: @"a"];
	[array addObject: @"b"];
	[array addObject: @"c"];
	@autoreleasepool {
		COPath *br1 = [COPath brokenPath];
		COPath *br2 = [COPath brokenPath];
		COPath *br3 = [COPath brokenPath];
		[array replaceReferenceAtIndex: 0 withReference: br1];
		[array replaceReferenceAtIndex: 1 withReference: br2];
		[array replaceReferenceAtIndex: 2 withReference: br3];
	}
	// Ensure the array retained all
	UKTrue([[array referenceAtIndex: 0] isBroken]);
	UKTrue([[array referenceAtIndex: 1] isBroken]);
	UKTrue([[array referenceAtIndex: 2] isBroken]);
}

@end

#pragma mark - TestUnsafeRetainedMutableSet

@interface TestUnsafeRetainedMutableSet : NSObject <UKTest>
{
	COUnsafeRetainedMutableSet *set;
}

@end

@implementation TestUnsafeRetainedMutableSet

- (id)init
{
	SUPERINIT;
	set = [COUnsafeRetainedMutableSet new];
	[set beginMutation];
	return self;
}

- (void) testDoesNotRetain
{
	__weak id weakReference = nil;
	
	@autoreleasepool {
		NSObject *content = [NSObject new];
		weakReference = content;
		[set addObject: content];
		UKIntsEqual(1, [set count]);
		UKNotNil(weakReference);
	}
	
	UKNil(weakReference);
}

- (void) testDoesRetainCOPath
{
	__weak COPath *weakReference = nil;
	
	@autoreleasepool {
		COPath *p = [COPath pathWithPersistentRoot: [ETUUID UUID]];
		weakReference = p;
		[set addReference: p];
		UKNotNil(weakReference);
	}
	
	// Going out of scope should not deallocate it
	@autoreleasepool {
		UKObjectKindOf(weakReference, COPath);
	}
	
	// Removing it from the collection should deallocate it
	@autoreleasepool {
		[set removeReference: weakReference];
	}
	UKNil(weakReference);
}

- (void) testDisallowsDuplicates
{
	[set addObject: @"a"];
	[set addObject: @"b"];
	[set addObject: [NSString stringWithFormat: @"a"]];
	UKObjectsEqual(S(@"a", @"b"), set);
}

- (void) testAllowsReinsertion
{
	[set addObject: @"a"];
	UKObjectsEqual(S(@"a"), set);
	[set removeObject: @"a"];
	UKObjectsEqual(S(), set);
	[set addObject: @"a"];
	UKObjectsEqual(S(@"a"), set);
}

- (void)testMultipleBrokenPaths
{
	UKIntsEqual(0, set.count);
	[set addObject: @"a"];
	[set addObject: @"b"];
	UKIntsEqual(2, set.count);
	
	@autoreleasepool {
		[set removeReference: @"b"];
		[set addReference: [COPath brokenPath]];
		UKIntsEqual(1, set.count);
	}
	
	@autoreleasepool {
		[set removeReference: @"a"];
		[set addReference: [COPath brokenPath]];
		UKIntsEqual(0, set.count);
	}
	
	UKIntsEqual(0, set.allObjects.count);
	UKIntsEqual(2, set.allReferences.count);
	
	for (COPath *path in set.allReferences)
	{
		UKTrue(path.isBroken);
	}
}

@end
