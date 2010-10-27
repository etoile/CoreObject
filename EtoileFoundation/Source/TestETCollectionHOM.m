/*
	TestETCollectionHOM.m

	Unit tests for higher-order messaging on collections.

	Copyright (C) 2009 Niels Grewe

	Author:  Niels Grewe <niels.grewe@halbordnung.de>
	Date:  June 2009

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
	* Neither the name of the Etoile project nor the names of its contributors
	  may be used to endorse or promote products derived from this software
	  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
	THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "Macros.h"
#import "ETCollection.h"
#import "ETCollection+HOM.h"
#import "NSObject+Model.h"
#import "EtoileCompatibility.h"

#define	INPUT_ARRAY NSArray *inputArray = A(@"foo",@"bar");
#define INPUT_DICTIONARY NSDictionary *inputDictionary = D(@"foo",@"one",@"bar",@"two");
#define	INPUT_SET NSSet *inputSet = [NSSet setWithArray: A(@"foo",@"bar")];
#define INPUT_COUNTED_SET NSCountedSet *inputCountedSet = [NSCountedSet set]; \
	[inputCountedSet addObject: @"foo"]; \
	[inputCountedSet addObject: @"bar"]; \
	[inputCountedSet addObject: @"foo"];
#define INPUT_INDEX_SET NSIndexSet *inputIndexSet = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0,5)];

#define INPUT_MUTABLE_ARRAY NSMutableArray *array = [NSMutableArray arrayWithObjects: @"foo",@"bar", nil];
#define INPUT_MUTABLE_DICTIONARY NSMutableDictionary *dictionary = [NSMutableDictionary \
	dictionaryWithObjectsAndKeys: @"foo",@"one",@"bar",@"two",nil];
#define INPUT_MUTABLE_SET NSMutableSet *set = [NSMutableSet setWithArray: A(@"foo",@"bar")];
#define INPUT_MUTABLE_COUNTED_SET	NSCountedSet *countedSet = [NSCountedSet set]; \
	[countedSet addObject: @"foo"]; \
	[countedSet addObject: @"bar"]; \
	[countedSet addObject: @"foo"];
#define INPUT_MUTABLE_INDEX_SET NSRange r = NSMakeRange(0,5); \
	NSMutableIndexSet *indexSet = [NSMutableIndexSet \
	                                       indexSetWithIndexesInRange: r];
#define ATTRIBUTED_OBJECTS TestAttributedObject *attrObject = [[[TestAttributedObject alloc] init] autorelease]; \
    TestAttributedObject *anotherAttrObject = [[[TestAttributedObject alloc] init] autorelease]; \
	[attrObject setString: @"foo"]; \
	[attrObject setNumber: [NSNumber numberWithInt: 1]]; \
	[anotherAttrObject setString: @"bar"]; \
	[anotherAttrObject setNumber: [NSNumber numberWithInt: 2]];

#define _INPUT_ATTR_ARRAY NSMutableArray *attrArray = [NSMutableArray arrayWithObjects: \
	                                     attrObject, anotherAttrObject, nil];
#define INPUT_ATTR_ARRAY ATTRIBUTED_OBJECTS \
	_INPUT_ATTR_ARRAY

#define _INPUT_ATTR_SET NSMutableSet *attrSet = [NSMutableSet setWithArray: A(attrObject, anotherAttrObject)];
#define INPUT_ATTR_SET ATTRIBUTED_OBJECTS \
	_INPUT_ATTR_SET
#define _INPUT_ATTR_COUNTED_SET NSCountedSet *attrCountedSet = [NSCountedSet set]; \
	[attrCountedSet addObject: attrObject]; \
	[attrCountedSet addObject: attrObject]; \
	[attrCountedSet addObject: anotherAttrObject];
#define INPUT_ATTR_COUNTED_SET ATTRIBUTED_OBJECTS \
	_INPUT_ATTR_COUNTED_SET
#define _INPUT_ATTR_DICTIONARY NSMutableDictionary *attrDict = [NSMutableDictionary \
	 dictionaryWithObjectsAndKeys: attrObject, @"one", \
	                        anotherAttrObject, @"two", nil];
#define INPUT_ATTR_DICTIONARY ATTRIBUTED_OBJECTS \
	_INPUT_ATTR_DICTIONARY
#define INPUT_ATTR_COLLECTIONS ATTRIBUTED_OBJECTS \
	_INPUT_ATTR_ARRAY \
	_INPUT_ATTR_SET \
	_INPUT_ATTR_COUNTED_SET \
	_INPUT_ATTR_DICTIONARY
@interface NSNumber (ETTestHOM)
@end

@implementation NSNumber (ETTestHOM)
- (NSNumber*)twice
{
	int out = [self intValue] * 2;
	return [NSNumber numberWithInt: out];
}
- (NSNumber*)addNumber: (NSNumber*)aNumber
{
	int out = [self intValue] + [aNumber intValue];
	return [NSNumber numberWithInt: out];
}
@end

@interface NSString (ETTestHOM)
@end

@implementation NSString (ETTestHOM)
- (id)getNil
{
	return nil;
}
- (NSString*)stringByAppendingString: (NSString*) firstString
                           andString: (NSString*)secondString
{
	return [[self stringByAppendingString: firstString] stringByAppendingString: secondString];
}

- (BOOL)isEqualToString: (NSString *) firstString
              andString: (NSString *) secondString
{
	return [self isEqualToString: [firstString stringByAppendingString: secondString]];
}
@end

@interface TestAttributedObject: NSObject
{
	NSString *stringAttribute;
	NSNumber *numericAttribute;
}
@end

@implementation TestAttributedObject
- (NSNumber *)numberAttribute
{
	return numericAttribute;
}

- (NSString *)stringAttribute
{
	return stringAttribute;
}

- (void)setNumber: (NSNumber *)aNumber
{
	ASSIGN(numericAttribute, aNumber);
}

- (void)setString: (NSString *)aString
{
	ASSIGN(stringAttribute, aString);
}

- (id)init
{
	SUPERINIT
	stringAttribute = nil;
	numericAttribute = nil;
	return self;
}

- (id)copyWithZone: (NSZone *)zone
{
	TestAttributedObject *newObject = [[TestAttributedObject allocWithZone: zone] init];
	newObject->stringAttribute = [stringAttribute copyWithZone: zone];
	newObject->numericAttribute = [numericAttribute copyWithZone: zone];
	return newObject;
}

DEALLOC( [stringAttribute release]; [numericAttribute release];)

@end

@interface TestETCollectionHOM: NSObject <UKTest>
@end

@implementation TestETCollectionHOM

/* -displayName is is defined in an NSObject category */
- (void)testDisplayNameAsArgumentMessage
{
	NSSet *inputSet = S(@"bla", @"bli", [NSNumber numberWithInt: 5]);
	NSSet *mappedSet = (NSSet *)[[inputSet mappedCollection] displayName];

	UKTrue([mappedSet containsObject: @"bla"]);
	UKTrue([mappedSet containsObject: @"bli"]);
	UKTrue([mappedSet containsObject: @"5"]);
}

/* -class is defined on both NSObject and NSProxy */
- (void)testClassAsArgumentMessage
{
	NSSet *inputSet = S([NSAffineTransform transform], [NSAffineTransform transform], [NSNull null]);
	NSSet *mappedSet = (NSSet *)[[inputSet mappedCollection] class];

	UKTrue([mappedSet containsObject: [NSAffineTransform class]]);
	UKTrue([mappedSet containsObject: [NSNull class]]);
}

- (void)testMappedEmptyCollection
{
	UKTrue([(id)[[[NSArray array] mappedCollection] uppercaseString] isEmpty]);
	UKTrue([(id)[[[NSSet set] mappedCollection] uppercaseString] isEmpty]);
	UKTrue([(id)[[[NSCountedSet set] mappedCollection] uppercaseString] isEmpty]);
	UKTrue([(id)[[[NSIndexSet indexSet] mappedCollection] twice] isEmpty]);
	UKTrue([(id)[[[NSDictionary dictionary] mappedCollection] uppercaseString] isEmpty]);
}

- (void)testMappedArray
{
	INPUT_ARRAY
	NSArray *mappedArray = (NSArray*)[[inputArray mappedCollection] uppercaseString];

	UKTrue([mappedArray containsObject: @"FOO"]);
	UKTrue([mappedArray containsObject: @"BAR"]);
	UKFalse([mappedArray containsObject: @"foo"]);
	UKFalse([mappedArray containsObject: @"bar"]);
}

- (void)testMappedSet
{
	INPUT_SET
	NSSet *mappedSet = (NSSet*)[[inputSet mappedCollection] uppercaseString];

	UKTrue([mappedSet containsObject: @"FOO"]);
	UKTrue([mappedSet containsObject: @"BAR"]);
	UKFalse([mappedSet containsObject: @"foo"]);
	UKFalse([mappedSet containsObject: @"bar"]);
}

- (void)testMappedCountedSet
{
	INPUT_COUNTED_SET
	NSCountedSet *mappedCountedSet = (NSCountedSet*)[[inputCountedSet mappedCollection] uppercaseString];

	UKTrue([mappedCountedSet containsObject: @"FOO"]);
	UKTrue([mappedCountedSet containsObject: @"BAR"]);
	UKFalse([mappedCountedSet containsObject: @"foo"]);
	UKFalse([mappedCountedSet containsObject: @"bar"]);
	UKIntsEqual([inputCountedSet countForObject: @"foo"],
	            [mappedCountedSet countForObject: @"FOO"]);
	UKIntsEqual([inputCountedSet countForObject: @"bar"],
	            [mappedCountedSet countForObject: @"BAR"]);
}

- (void)testMappedIndexSet
{
	INPUT_INDEX_SET
	NSIndexSet *mappedIndexSet = (NSIndexSet*)[[inputIndexSet mappedCollection]	twice];

	NSEnumerator *indexEnumerator = [(NSArray*)inputIndexSet objectEnumerator];
	FOREACHE(inputIndexSet,number,id,indexEnumerator)
	{
		int input = [(NSNumber*)number intValue];

		UKTrue([mappedIndexSet containsIndex: input*2]);
	}
}

- (void)testMappedDictionary
{
	INPUT_DICTIONARY
	NSDictionary *mappedDictionary = (NSDictionary*)[[inputDictionary mappedCollection] uppercaseString];

	UKObjectsEqual([mappedDictionary objectForKey: @"one"],@"FOO");
	UKObjectsEqual([mappedDictionary objectForKey: @"two"],@"BAR");
}

- (void)testMapEmptyCollection
{
	UKTrue([(id)[[[NSMutableArray array] map] uppercaseString] isEmpty]);
	UKTrue([(id)[[[NSMutableSet set] map] uppercaseString] isEmpty]);
	UKTrue([(id)[[[NSCountedSet set] map] uppercaseString] isEmpty]);
	UKTrue([(id)[[[NSMutableIndexSet indexSet] map] twice] isEmpty]);
	UKTrue([(id)[[[NSMutableDictionary dictionary] map] uppercaseString] isEmpty]);
}

- (void)testMapArray
{
	INPUT_MUTABLE_ARRAY
	[[array map] uppercaseString];

	UKTrue([array containsObject: @"FOO"]);
	UKTrue([array containsObject: @"BAR"]);
	UKFalse([array containsObject: @"foo"]);
	UKFalse([array containsObject: @"bar"]);
}

- (void)testMapSet
{
	INPUT_MUTABLE_SET
	[[set map] uppercaseString];

	UKTrue([set containsObject: @"FOO"]);
	UKTrue([set containsObject: @"BAR"]);
	UKFalse([set containsObject: @"foo"]);
	UKFalse([set containsObject: @"bar"]);
}

- (void)testMapCountedSet
{
	INPUT_MUTABLE_COUNTED_SET
	int countOfFoo = [countedSet countForObject: @"foo"];
	int countOfBar = [countedSet countForObject: @"bar"];
	[[countedSet map] uppercaseString];

	UKTrue([countedSet containsObject: @"FOO"]);
	UKTrue([countedSet containsObject: @"BAR"]);
	UKFalse([countedSet containsObject: @"foo"]);
	UKFalse([countedSet containsObject: @"bar"]);
	UKIntsEqual(countOfFoo, [countedSet countForObject: @"FOO"]);
	UKIntsEqual(countOfBar, [countedSet countForObject: @"BAR"]);
}

- (void)testMapIndexSet
{
	INPUT_MUTABLE_INDEX_SET
	NSIndexSet *origIndexSet = [NSIndexSet indexSetWithIndexesInRange: r];
	[[indexSet map] twice];
	NSEnumerator *indexEnumerator = [(NSArray*)origIndexSet objectEnumerator];
	FOREACHE(origIndexSet, number, id, indexEnumerator)
	{
		int input = [(NSNumber*)number intValue];

		UKTrue([indexSet containsIndex: input*2]);
	}
}

- (void)testMapDictionary
{
	INPUT_MUTABLE_DICTIONARY
	[[dictionary map] uppercaseString];

	UKObjectsEqual([dictionary objectForKey: @"one"],@"FOO");
	UKObjectsEqual([dictionary objectForKey: @"two"],@"BAR");
}

- (void)testMapNilSubstitution
{
	INPUT_ARRAY
	INPUT_MUTABLE_ARRAY
	NSArray *mappedArray = (NSArray*)[[inputArray mappedCollection] getNil];
	[[array map] getNil];

	UKIntsEqual([inputArray count],[mappedArray count]);
	UKIntsNotEqual(0,[array count]);
}

- (void)testFoldEmptyCollection
{
	UKNil([[[NSMutableArray array] leftFold] stringByAppendingString: @"foo"]);
	UKNil([[[NSMutableSet set] leftFold] stringByAppendingString: @"foo"]);
	UKNil([[[NSCountedSet set] leftFold] stringByAppendingString: @"foo"]);
	UKNil([[[NSMutableIndexSet indexSet] leftFold] addNumber: [NSNumber numberWithInt: 0]]);
	UKNil([[[NSMutableDictionary dictionary] leftFold] stringByAppendingString: @"foo"]);
}

- (void)testFoldArray
{
	INPUT_ARRAY

	UKObjectsEqual(@"letters: foobar",[[inputArray leftFold]
	stringByAppendingString: @"letters: "]);
	UKObjectsEqual(@"foobar: letters",[[inputArray rightFold]
	stringByAppendingString: @": letters"]);
}

- (void)testFoldSet
{
	INPUT_SET
	NSString* folded = [[inputSet leftFold] stringByAppendingString: @""];

	UKTrue(([folded isEqual: @"foobar"] || [folded isEqual: @"barfoo"]));
}

- (void)testFoldCountedSet
{
	INPUT_COUNTED_SET
	NSString *folded = [[inputCountedSet leftFold] stringByAppendingString: @""];

	UKTrue([S(@"foofoobar", @"barfoofoo", @"foobarfoo") containsObject: folded]);
}

- (void)testFoldIndexSet
{
	INPUT_INDEX_SET

	UKIntsEqual(10,[(NSNumber*)[[inputIndexSet leftFold] addNumber:
	                   [NSNumber numberWithInt: 0]] intValue]);
}

- (void)testFilterEmptyCollection
{
	NSMutableArray *array = [NSMutableArray array];
	NSMutableSet *set = [NSMutableSet set];
	NSCountedSet *countedSet = [NSCountedSet set];
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	[[array filter] isEqualToString: @"foo"];
	[[set filter] isEqualToString: @"foo"];
	[[countedSet filter] isEqualToString: @"foo"];
	NSNumber *nb = [NSNumber numberWithInt: 2];
	[[indexSet filter] isEqualToNumber: nb];
	[[dict filter] isEqualToString: @"foo"];

	UKTrue([array isEmpty]);
	UKTrue([set isEmpty]);
	UKTrue([countedSet isEmpty]);
	UKTrue([indexSet isEmpty]);
	UKTrue([dict isEmpty]);
}

- (void)testFilterEmptyCollectionWithTwoMessages
{
	NSMutableArray *array = [NSMutableArray array];
	NSMutableSet *set = [NSMutableSet set];
	NSCountedSet *countedSet = [NSCountedSet set];
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	[[[array filter] lastObject] isEqualToString: @"foo"];
	[[[set filter] lastObject] isEqualToString: @"foo"];
	[[[countedSet filter] lastObject] isEqualToString: @"foo"];
	NSNumber *nb = [NSNumber numberWithInt: 2];
	[[[indexSet filter] lastObject] isEqualToNumber: nb];
	[[[dict filter] lastObject] isEqualToString: @"foo"];

	UKTrue([array isEmpty]);
	UKTrue([set isEmpty]);
	UKTrue([countedSet isEmpty]);
	UKTrue([indexSet isEmpty]);
	UKTrue([dict isEmpty]);
}

- (void)testFilterArraysAndSets
{
	INPUT_MUTABLE_ARRAY
	INPUT_MUTABLE_SET
	INPUT_MUTABLE_COUNTED_SET
	NSArray *someInputs = A(array,set,countedSet);
	FOREACHI(someInputs, collection)
	{
		[[(NSMutableArray*)collection filter]isEqualToString: @"foo"];

		UKTrue([(NSMutableArray*)collection containsObject: @"foo"]);
		UKFalse([(NSMutableArray*)collection containsObject: @"bar"]);
	}
}

- (void)testFilterDictionary
{
	INPUT_MUTABLE_DICTIONARY
	[[dictionary filter] isEqualToString: @"foo"];

	UKObjectsEqual(@"foo",[dictionary objectForKey: @"one"]);
	UKNil([dictionary objectForKey: @"two"]);
}

- (void)testFilterIndexSet
{
	INPUT_MUTABLE_INDEX_SET
	[[indexSet filter] isEqualToNumber: [NSNumber numberWithInt: 2]];
	NSEnumerator *indexEnumerator = [(NSArray*)indexSet objectEnumerator];

	FOREACHE(indexSet,anIndex,id,indexEnumerator)
	{
		UKIntsEqual(2,[(NSNumber*)anIndex intValue]);
	}
}

- (void)testAttributeAwareFilterArray
{
	INPUT_ATTR_ARRAY
	[[[attrArray filter] stringAttribute] isEqualToString: @"foo"];

	UKTrue([attrArray containsObject: attrObject]);
	UKFalse([attrArray containsObject: anotherAttrObject]);
}

- (void)testAttributeAwareFilterSet
{
	INPUT_ATTR_SET
	[[[attrSet filter] stringAttribute] isEqualToString: @"foo"];

	UKTrue([attrSet containsObject: attrObject]);
	UKFalse([attrSet containsObject: anotherAttrObject]);
}

- (void)testAttributeAwareFilterCountedSet
{
	INPUT_ATTR_COUNTED_SET
	[[[attrCountedSet filter] stringAttribute] isEqualToString: @"foo"];

	UKTrue([attrCountedSet containsObject: attrObject]);
	UKIntsEqual(2, [attrCountedSet countForObject: attrObject]);
	UKFalse([attrCountedSet containsObject: anotherAttrObject]);
}
- (void)testAttributeAwareFilterDictionary
{
	INPUT_ATTR_DICTIONARY
	[[[attrDict filter] stringAttribute] isEqualToString: @"foo"];

	UKObjectsEqual(attrObject, [attrDict objectForKey: @"one"]);
	UKNil([attrDict objectForKey: @"two"]);
}

- (void)testDeepAttributeAwareFilter
{
	INPUT_ATTR_COLLECTIONS
	NSArray *someInputs = A(attrArray,attrSet,attrCountedSet,attrDict);
	FOREACHI(someInputs, collection)
	{
		[[[[(NSMutableArray*)collection filter] numberAttribute] twice] isEqualToNumber:
		                                          [NSNumber numberWithInt: 4]];
		if ((void*)collection == (void*)attrDict)
		{
			UKObjectsEqual(anotherAttrObject, [attrDict objectForKey: @"two"]);
			UKNil([attrDict objectForKey: @"one"]);
		}
		else
		{
			UKTrue([(NSMutableArray*)collection containsObject: anotherAttrObject]);
			UKFalse([(NSMutableArray*)collection containsObject: attrObject]);
		}
	}
}

- (void)testfilterOut
{
	NSMutableArray *input = [NSMutableArray arrayWithObjects: @"foo", @"bar", nil];
	[[input filterOut] isEqualToString: @"bar"];

	UKTrue([input containsObject: @"foo"]);
	UKFalse([input containsObject: @"bar"]);
}

- (void)testZippedEmptyCollection
{
	NSArray *second = A(@"bar", @"BAR");

	UKTrue([(id)[[[NSMutableArray array] zippedCollectionWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
	UKTrue([(id)[[[NSMutableSet set] zippedCollectionWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
	UKTrue([(id)[[[NSCountedSet set] zippedCollectionWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
	UKTrue([(id)[[[NSMutableIndexSet indexSet] zippedCollectionWithCollection: second]
		addNumber: [NSNumber numberWithInt: 0]] isEmpty]);
	UKTrue([(id)[[[NSMutableDictionary dictionary] zippedCollectionWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
}

- (void)testZippedArray
{
	NSArray *first = A(@"foo", @"FOO");
	NSArray *second = A(@"bar", @"BAR",@"bar");
	NSArray *result = (NSArray*)[[first zippedCollectionWithCollection: second] stringByAppendingString: nil];

	if (2 == [result count])
	{
		UKTrue([[result objectAtIndex: 0] isEqual: @"foobar"]);
		UKTrue([[result objectAtIndex: 1] isEqual: @"FOOBAR"]);
	}
	else
	{
		UKFail();
	}

}

- (void)testZippedDictionary
{
	INPUT_DICTIONARY
	NSDictionary *result = (NSDictionary*)[[inputDictionary zippedCollectionWithCollection: inputDictionary] stringByAppendingString: nil];

	UKObjectsEqual([result objectForKey: @"one"],@"foofoo");
	UKObjectsEqual([result objectForKey: @"two"],@"barbar");
}

- (void)testZippedSet
{
	INPUT_SET
	NSSet *result = (NSSet*)[[inputSet zippedCollectionWithCollection: inputSet] stringByAppendingString: nil];

	// FIXME: This test wrongly assumes that sets are ordered. Since the
	// implementation behaves that way, that's not a problem (yet).
	UKTrue([result containsObject: @"foofoo"]);
	UKTrue([result containsObject: @"barbar"]);
}

- (void)testZippedCountedSet
{
	INPUT_COUNTED_SET
	NSCountedSet *result = (NSCountedSet*)[[inputCountedSet zippedCollectionWithCollection: inputCountedSet]
	                                        stringByAppendingString: nil];

	UKTrue([result containsObject: @"foofoo"]);
	UKTrue([result containsObject: @"barbar"]);
	UKIntsEqual(2,[result countForObject: @"foofoo"]);
	UKIntsEqual(1,[result countForObject: @"barbar"]);
}

- (void)testZippedIndexSet
{
	INPUT_INDEX_SET
	NSIndexSet *result = (NSIndexSet*)[[inputIndexSet zippedCollectionWithCollection: inputIndexSet] addNumber: nil];
	NSEnumerator *indexEnumerator = [(NSArray*)inputIndexSet objectEnumerator];

	FOREACHE(inputIndexSet,number,id,indexEnumerator)
	{
		UKTrue([result containsIndex: [[(NSNumber*)number twice] unsignedIntValue]]);
	}
}

- (void)testZipEmptyCollection
{
	NSArray *second = A(@"bar", @"BAR");

	UKTrue([(id)[[[NSMutableArray array] zipWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
	UKTrue([(id)[[[NSMutableSet set] zipWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
	UKTrue([(id)[[[NSCountedSet set] zipWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
	UKTrue([(id)[[[NSMutableIndexSet indexSet] zipWithCollection: second]
		addNumber: [NSNumber numberWithInt: 0]] isEmpty]);
	UKTrue([(id)[[[NSMutableDictionary dictionary] zipWithCollection: second]
		stringByAppendingString: @"foo"] isEmpty]);
}

- (void)testZipArray
{
	INPUT_MUTABLE_ARRAY
	[[array zipWithCollection: array] stringByAppendingString: nil];

	UKTrue([array containsObject: @"foofoo"]);
	UKTrue([array containsObject: @"barbar"]);
	UKFalse([array containsObject: @"foo"]);
	UKFalse([array containsObject: @"bar"]);
}

- (void)testZipDict
{
	INPUT_MUTABLE_DICTIONARY
	[[dictionary zipWithCollection: dictionary] stringByAppendingString: nil];

	UKObjectsEqual(@"foofoo",[dictionary objectForKey: @"one"]);
	UKObjectsEqual(@"barbar",[dictionary objectForKey: @"two"]);
}

- (void)testZipSet
{
	INPUT_MUTABLE_SET
	[[set zipWithCollection: set] stringByAppendingString: nil];

	UKTrue([set containsObject: @"foofoo"]);
	UKTrue([set containsObject: @"barbar"]);
	UKFalse([set containsObject: @"foo"]);
	UKFalse([set containsObject: @"foo"]);
}

- (void)testZipCountedSet
{
	INPUT_MUTABLE_COUNTED_SET
	[[countedSet zipWithCollection: countedSet] stringByAppendingString: nil];

	UKIntsEqual(2,[countedSet countForObject: @"foofoo"]);
	UKIntsEqual(1,[countedSet countForObject: @"barbar"]);
	UKIntsEqual(0,[countedSet countForObject: @"foo"]);
	UKIntsEqual(0,[countedSet countForObject: @"bar"]);
}

- (void)testZipIndexSet
{
	INPUT_MUTABLE_INDEX_SET
	NSIndexSet *origIndexSet = [NSIndexSet indexSetWithIndexesInRange: r];
	[[indexSet zipWithCollection: indexSet] addNumber: nil];
	NSEnumerator *indexEnumerator = [(NSArray*)origIndexSet objectEnumerator];

	FOREACHE(origIndexSet, number, NSNumber*, indexEnumerator)
	{
		UKTrue([indexSet containsIndex: [[number twice] unsignedIntValue]]);
	}
}

- (void)testMappedArrayWithEach
{
	NSArray *first = A(@"foo", @"FOO");
	NSArray *second = A(@"bar", @"BAR");
	NSArray *result = (NSArray*)[[first mappedCollection] stringByAppendingString: [second each]];

	if (4 == [result count])
	{
		UKTrue([[result objectAtIndex: 0] isEqual: @"foobar"]);
		UKTrue([[result objectAtIndex: 1] isEqual: @"fooBAR"]);
		UKTrue([[result objectAtIndex: 2] isEqual: @"FOObar"]);
		UKTrue([[result objectAtIndex: 3] isEqual: @"FOOBAR"]);
	}
	else
	{
		UKFail();
	}
}

- (void)testMapArrayWithEach
{
	NSMutableArray *first = [[NSMutableArray alloc] initWithArray: A(@"foo",@"FOO")];
	NSArray *second = A(@"bar",@"BAR");
	[[first map] stringByAppendingString: [second each]];

	if (4 == [first count])
	{
		UKTrue([[first objectAtIndex: 0] isEqual: @"foobar"]);
		UKTrue([[first objectAtIndex: 1] isEqual: @"FOObar"]);
		UKTrue([[first objectAtIndex: 2] isEqual: @"fooBAR"]);
		UKTrue([[first objectAtIndex: 3] isEqual: @"FOOBAR"]);
	}
	else
	{
		UKFail();
	}
}

- (void)testMappedDictionaryWithEach
{
	NSDictionary *first = D(@"foo",@"one",@"FOO",@"two");
	NSArray *second = A(@"bar",@"BAR");
	NSDictionary *result = (NSDictionary*)[[first mappedCollection] stringByAppendingString: [second each]];
	NSEnumerator *resultEnumerator = [result objectEnumerator];
	NSMutableArray *expected = [NSMutableArray arrayWithObjects: @"fooBAR",@"FOObar",@"FOOBAR",@"foobar", nil];

	UKIntsEqual(4,[result count]);
	FOREACHE(result, object, id, resultEnumerator)
	{
		UKTrue([expected containsObject: object]);
		[expected removeObject: object];
	}
}

// Test lots of elements here because doing this correctly is tricky.
- (void)testMapDictionaryWithEach
{
	NSMutableDictionary *first = [NSMutableDictionary dictionaryWithObjectsAndKeys:
	    @"foo",@"one",@"FOO",@"two",@"Foo",@"three",nil];
	NSArray *second = A(@"bar",@"BAR",@"Bar",@"BAr");
	[[first map] stringByAppendingString: [second each]];
	NSEnumerator *firstEnumerator = [first objectEnumerator];
	NSMutableArray *expected = [NSMutableArray arrayWithObjects: @"FOOBar",
	@"FOOBAR", @"fooBAR", @"FOOBAr", @"fooBAr", @"FooBAr", @"FooBAR", @"Foobar",
	@"foobar", @"FOObar", @"fooBar",  @"FooBar", nil];

	UKIntsEqual(12,[first count]);
	FOREACHE(first, object, id, firstEnumerator)
	{
		UKTrue([expected containsObject: object]);
		[expected removeObject: object];
	}
}

- (void)testMappedSetWithEach
{
	NSSet *first = S(@"foo",@"FOO");
	NSArray *second = A(@"bar",@"BAR");
	NSSet *result = (NSSet*)[[first mappedCollection] stringByAppendingString: [second each]];
	NSMutableArray *expected = [NSMutableArray arrayWithObjects: @"fooBAR",@"FOObar",@"FOOBAR",@"foobar", nil];

	UKIntsEqual(4,[result count]);
	FOREACHI(result,object)
	{
		UKTrue([expected containsObject: object]);
		[expected removeObject: object];
	}
}

- (void)testMapSetWithEach
{
	NSMutableSet *first = [NSMutableSet setWithObjects: @"foo", @"FOO", nil];
	NSArray *second = A(@"bar",@"BAR");
	[[first map] stringByAppendingString: [second each]];
	NSMutableArray *expected = [NSMutableArray arrayWithObjects: @"fooBAR",@"FOObar",@"FOOBAR",@"foobar", nil];

	UKIntsEqual(4,[first count]);
	FOREACHI(first,object)
	{
		UKTrue([expected containsObject: object]);
		[expected removeObject: object];
	}

}

- (void)testMappedCountedSetWithEach
{
	NSCountedSet *first = [NSCountedSet setWithObjects: @"foo", @"FOO", nil];
	[first addObject: @"foo"];
	NSArray *second = A(@"bar",@"BAR");
	NSCountedSet *result = (NSCountedSet*)[[first mappedCollection] stringByAppendingString: [second each]];

	UKIntsEqual(2,[result countForObject: @"foobar"]);
	UKIntsEqual(2,[result countForObject: @"fooBAR"]);
	UKIntsEqual(1,[result countForObject: @"FOObar"]);
	UKIntsEqual(1,[result countForObject: @"FOOBAR"]);
	UKIntsEqual(0,[result countForObject: @"foo"]);
	UKIntsEqual(0,[result countForObject: @"FOO"]);
}

- (void)testMapCountedSetWithEach
{
	NSCountedSet *first = [NSCountedSet setWithObjects: @"foo", @"FOO", nil];
	[first addObject: @"foo"];
	NSArray *second = A(@"bar",@"BAR");
	[[first map] stringByAppendingString: [second each]];

	UKIntsEqual(2,[first countForObject: @"foobar"]);
	UKIntsEqual(2,[first countForObject: @"fooBAR"]);
	UKIntsEqual(1,[first countForObject: @"FOObar"]);
	UKIntsEqual(1,[first countForObject: @"FOOBAR"]);
	UKIntsEqual(0,[first countForObject: @"foo"]);
	UKIntsEqual(0,[first countForObject: @"FOO"]);
}

- (void)testMappedIndexSetWithEach
{
	NSIndexSet *first = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0,2)];
	NSArray *second = A([NSNumber numberWithInt: 10], [NSNumber numberWithInt: 20]);
	NSIndexSet *result = (NSIndexSet*)[[first mappedCollection] addNumber: [second each]];

	UKTrue([result containsIndex: 10]);
	UKTrue([result containsIndex: 20]);
	UKTrue([result containsIndex: 11]);
	UKTrue([result containsIndex: 21]);
	UKFalse([result containsIndex: 0]);
	UKFalse([result containsIndex: 1]);
}

- (void)testMapIndexSetWithEach
{
	NSMutableIndexSet *first = [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(0,2)];
	NSArray *second = A([NSNumber numberWithInt: 10], [NSNumber numberWithInt: 20]);
	[[first map] addNumber: [second each]];

	UKTrue([first containsIndex: 10]);
	UKTrue([first containsIndex: 20]);
	UKTrue([first containsIndex: 11]);
	UKTrue([first containsIndex: 21]);
	UKFalse([first containsIndex: 0]);
	UKFalse([first containsIndex: 1]);
}

- (void)testMappedArrayWithDeepEach
{
	NSArray *first = A(@"foo",@"bar");
	NSArray *second = A(@"Foo",@"Bar");
	NSArray *third = A(@"FOO",@"BAR");
	NSArray *result = (NSArray*)[[first mappedCollection] stringByAppendingString: [second each]
	                                                                    andString: [third each]];
	NSMutableArray *expected = [NSMutableArray arrayWithObjects: @"fooFooFOO",
	     @"fooFooBAR", @"fooBarFOO", @"fooBarBAR", @"barFooFOO", @"barFooBAR",
	     @"barBarFOO", @"barBarBAR", nil];

	UKIntsEqual(8, [result count]);
	FOREACHI(result, object)
	{
		UKTrue([expected containsObject: object]);
		[expected removeObject: object];
	}
}

- (void)testFilterArrayWithEach
{
	NSMutableArray *first = [NSMutableArray arrayWithObjects: @"foo",@"bar",@"BAR",@"Foo", nil];
	NSArray *second = A(@"foo",@"Foo",@"FOO");
	[[first filter] isEqualToString: [second each]];
	NSArray *expected = A(@"foo",@"Foo");

	UKIntsEqual(2, [first count]);
	UKObjectsEqual(first, expected);
}

- (void)testFilterArrayWithDeepEach
{
	NSMutableArray *first = [NSMutableArray arrayWithObjects: @"foo",@"bar",@"BAR",@"Foo", nil];
	NSArray *second = A(@"f",@"F");
	NSArray *third = A(@"OO",@"oo");
	[[first filter] isEqualToString: [second each]
	                      andString: [third each]];
	NSArray *expected = A(@"foo",@"Foo");

	UKIntsEqual(2, [first count]);
	UKObjectsEqual(first, expected);
}

#if __has_feature(blocks)
// Test for block-variants

/*
 * NOTE: In the present implementation the handling of different collection
 * classes is independent from the handling of blocks/invocations. Hence we only
 * test the block-variants on NS(Mutable)Array. If the implementation changes in
 * the future so that handling of blocks depends on the collection class, it
 * will be necessary to add tests for NSDictionary, NSSet, NSIndexSet and their
 * mutable variants.
 */

#define MAP_BLOCK ^(id string){return [string uppercaseString];}
- (void)testBlockMappedArray
{
	INPUT_ARRAY
	NSArray *result = [inputArray mappedCollectionWithBlock: MAP_BLOCK];

	UKTrue([result containsObject: @"FOO"]);
	UKTrue([result containsObject: @"BAR"]);
	UKFalse([result containsObject: @"foo"]);
	UKFalse([result containsObject: @"bar"]);
}

- (void)testBlockMapArray
{
	INPUT_MUTABLE_ARRAY
	[array mapWithBlock: MAP_BLOCK];

	UKTrue([array containsObject: @"FOO"]);
	UKTrue([array containsObject: @"BAR"]);
	UKFalse([array containsObject: @"foo"]);
	UKFalse([array containsObject: @"bar"]);
}

- (void)testBlockFoldArray
{
	INPUT_ARRAY
	NSString *result = (NSString*)[inputArray leftFoldWithInitialValue: @"letters: "
	                                                         intoBlock:  ^(id acu, id el){return [acu stringByAppendingString: el];}];

	UKObjectsEqual(@"letters: foobar",result);
}

- (void)testBlockFilteredArray
{
	INPUT_ARRAY
	BOOL(^filterBlock)(id) = ^(id string){return [string isEqualToString: @"foo"];};
	NSArray *result = [inputArray filteredCollectionWithBlock: filterBlock];

	UKTrue([result containsObject: @"foo"]);
	UKFalse([result containsObject: @"bar"]);
}

- (void)testBlockFilterArray
{
	INPUT_MUTABLE_ARRAY
	BOOL(^filterBlock)(id) = ^(id string){return [string isEqualToString: @"foo"];};
	[array filterWithBlock: filterBlock];

	UKTrue([array containsObject: @"foo"]);
	UKFalse([array containsObject: @"bar"]);
}

- (void)testBlockZippedArray
{
	INPUT_ARRAY
	id(^zipBlock)(id,id) = ^(id first, id second){return [first stringByAppendingString: second];};
	NSArray *result = [inputArray zippedCollectionWithCollection: inputArray
	                                                    andBlock: zipBlock];

	UKTrue([result containsObject: @"foofoo"]);
	UKTrue([result containsObject: @"barbar"]);
	UKFalse([result containsObject: @"foo"]);
	UKFalse([result containsObject: @"bar"]);
}

- (void)testBlockZipArray
{
	INPUT_MUTABLE_ARRAY
	NSArray *second = A(@"foo",@"bar");
	id(^zipBlock)(id,id) = ^(id first, id second){return [first stringByAppendingString: second];};
	[array zipWithCollection: second andBlock: zipBlock];

	UKTrue([array containsObject: @"foofoo"]);
	UKTrue([array containsObject: @"barbar"]);
	UKFalse([array containsObject: @"foo"]);
	UKFalse([array containsObject: @"bar"]);
}
#endif
@end
