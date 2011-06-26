/**
	<abstract>NSObject and collection class additions like a collection 
	protocol.</abstract>

	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  September 2007
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>

/** Marks an element which shouldn't be considered bound to a particular index 
in an ordered collection or whose index isn't yet determined.<br /> 
For use cases, see ETCollectionMutation.

With EtoileUI, can be used to indicate a drop is not an insertion at precise 
index but a simple drop on. */
extern const NSUInteger ETUndeterminedIndex;

/* Collection Access and Mutation Protocols */

/** @group Collection Protocols

Basic collection protocol that all collections must support. EtoileFoundation 
extends Foundation classes such as NSArray, NSDictionary, NSSet and NSIndexSet 
to adopt this protocol. EtoileUI extends NSView in the same way.

With this protocol, the collection content can be accessed and queried in 
various ways but cannot be mutated.

Given most protocol method implementations remains the same accross collection 
classes, we provide ETCollectionTrait as a reusable ETCollection implementation.

The two primitives methods are -content and -contentArray. These methods must 
be implemented in the collection class in all cases. See ETCollectionTrait.

When you write a new class that includes a to-many relationship, it should 
conform to ETCollection. If several to-many relationships exist, you should 
pick the dominant relationship that best represents the main content. A good 
hint is to pick the most recurrent way to browse the content with a UI, and 
the relationship traversed in such a case.<br />
EtoileUI can automatically present collection-like content and support 
navigation into it when represented objects bound to ETLayoutItemGroup conform 
to ETCollection.

Note: In future, we will provide a viewpoint mechanism to view or traverse 
objects through their non-dominant to-many relationships. */ 
@protocol ETCollection
/** Returns whether the receiveir stores the elements in a sorted order or not. */
- (BOOL) isOrdered;
/** Returns YES when the collection contains no elements, otherwise returns NO. */
- (BOOL) isEmpty;
/** Returns the underlying data structure object holding the content or self 
when the protocol is adopted by a class which is a content data structure by 
itself (like NSArray, NSDictionary, NSSet etc.). 

Content by its very nature is always a collection of other objects. As such, 
content may hold one or no objects (empty collection).

When adopted, this method must never return nil. */
- (id) content;
/** Returns the content as a new NSArray-based collection of objects. 

When adopted, this method must never return nil, you should generally 
return an empty NSArray instead. */
- (NSArray *) contentArray;
/** Returns the number of elements hold by the receiver. */
- (NSUInteger) count;
/** Returns an enumerator which can be used as a conveniency to iterate over 
the elements of the content one-by-one. */
- (NSEnumerator *) objectEnumerator;
/** Returns whether the element is included in the collection. */
- (BOOL) containsObject: (id)anObject;
/** Returns whether every element in the given collection are included in the receiver. */
- (BOOL) containsCollection: (id <ETCollection>)objects;
@end

/** @group Collection Protocols 

Additional collection protocol that all mutable collections must support. 
EtoileFoundation extends Foundation classes such as NSMutableArray, 
NSMutableDictionary, NSMutableSet, NSCountedSet and NSMutableIndexSet 
to adopt this protocol. EtoileUI extends NSView in the same way.

Given most protocol method implementations remains the same accross collection 
classes, we provide ETMutableCollectionTrait as a reusable ETCollectionMutation 
implementation.

The two primitive methods are -insertObject:atIndex:hint: and 
-removeObject:atIndex:hint:. These methods must be implemented in the 
collection class in all cases. See ETMutableCollectionTrait. 

When you write a new class that includes a mutable to-many relationship, it should 
conform to ETCollectionMutation, based on the rules presented in ETCollection 
documentation.<br />
EtoileUI can automatically mutate collection-like content and support 
turning user actions (e.g. drag an drop) into collection operations, when 
represented objects bound to ETLayoutItemGroup conform to ETCollectionMutation 
in addition to ETCollection. */
@protocol ETCollectionMutation
/** Adds the element to the collection. 

A collection can raise an exception on a nil object.

When the collection is ordered, the element is inserted as the last element. */
- (void) addObject: (id)object;
/** Inserts the element at the given index in the collection.

A collection can raise an exception on a nil object. <br />
An ordered collection can raise an exception on an invalid index such as 
ETUndeterminedIndex (this is not the same behavior than -insertObject:atIndex:hint:).

When the collection is not ordered, the index is ignored and the behavior is 
the same than -addObject:. */
- (void) insertObject: (id)object atIndex: (NSUInteger)index;
/** Removes the element from the collection.

A collection can raise an exception on a nil object. */
- (void) removeObject: (id)object;
/** Removes the element at the given index from the collection.

An ordered collection can raise an exception on an invalid index such as 
ETUndeterminedIndex.

When the collection is not ordered, an exception should be raised. */
- (void) removeObjectAtIndex: (NSUInteger)index;
/** Inserts the element at the given index in the collection, by making 
adjustments based on the hint if needed.

The element to be inserted must never be nil. The collection can raise an 
exception in such case.

If the collection is not ordered, the index can be ignored (the insertion 
becomes an addition), but otherwise it must not.

If the index is ETUndeterminedIndex, the insertion must be treated as an 
addition and the object inserted in last position if the collection is 
ordered e.g. NSMutableArray. See also -addObject:.

If the hint is not nil, the collection can test the hint type. If the hint 
matches its expectation, it's up to the collection to choose another index 
and/or another element to insert. Both the custom index and element can be 
provided by the hint.<br />
The collection must continue to behave in a predictable way (as detailed 
above) when no hint is provided. */
- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
/** Removes the element at the given index from the collection, by making 
adjustments based on the hint if needed.

The element can be nil, but then the index must not be ETUndeterminedIndex. 
Otherwise the collection can raise an exception.

If the collection is not ordered, the index can be ignored, but otherwise it 
must not.

If the index is ETUndeterminedIndex, all occurences of the element must 
be removed from the collection.

If both the element and index are valid, the element should be ignored and 
priority must be given to the index to locate the objects to remove (this rule 
is subject to change a bit).

If the hint is not nil, the collection can test the hint type. If the hint 
matches its expectation, it's up to the collection to choose another index 
and/or another element to remove. Both the custom index and element can be 
provided by the hint.<br />
The collection must continue to behave in a predictable way (as detailed 
above) when no hint is provided.<br />
If the hint can provide both a custom element and index, as stated previously, 
priority must be given to the index to locate the objects to remove. */
- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
@end

/** @group Collection Protocols

Any mutable collection can also implement the optional methods listed below.

EtoileUI will use these methods when possible.<br />
Initially you can skip implementing them. Later, they can be implemented to 
speed up the communication between your model collections and the layout items 
that represent them at the UI level. In addition, these methods allows to react 
to batch insertion and removal at the model level (e.g. in reply to a pick and 
drop). 

You are not required to implement every method when a class adopts this informal 
protocol.

When  a collection is received in argument, the collection type can be checked 
to know whether the code needs to convert the collection or not, to remove or 
insert its content in the receiver. In most cases, the code below is a useless 
optimization (the else branch is good enough).

<example>
if ([[aCollection content] isArray] == NO)
{
	[personIvarArray addObjectsFromArray: (NSArray *)aCollection];
}
else
{
	[personIvarArray addObjectsFromArray: [aCollection contentArray]];
}
</example>

See NSObject+Model for other methods such as -isArray. */
@interface NSObject (ETBatchCollectionMutation)
/** Inserts the given collection elements at separate indexes.

When the collection is not ordered, the indexes are ignored.

The element are inserted one-by-one by increasing index value while iterating 
over the indexes. When the greatest index is reached and several elements remain  
to be inserted, they are inserted at that same index.<br />
For a more precise description of the behavior ordered collection should comply 
to, see -[NSArray insertObjects:atIndexes:] in Cocoa documentation. */
- (void) insertCollection: (id <ETCollection>)objects atIndexes: (NSIndexSet *)indexes;
/** Removes the elements from the collection. */
- (void) removesCollection: (id <ETCollection>)objects;
/** Removes the elements at the given indexes from the collection.

You should only implement this method when the collection is ordered. */
- (void) removeObjectAtIndexes: (NSIndexSet *)indexes;
@end

/** @group Collection Protocols

This trait implements all ETCollection protocol methods, except -content and 
-contentArray, for which concrete implementations must be provided by the 
target class.

Any method provided by ETCollectionTrait can be overriden by implementing the 
method in the target class.

Here is a simple example that implements a complete mutable collection API. In 
addition to ETCollectionTrait, it also leverages ETMutableCollectionTrait to do 
so.

<example>
@interface MyCollection : NSObject &gt;ETCollection, ETCollectionMutation&lt;
{
	NSMutableArray *things;
}

@end

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation

+ (void) initialize
{
	if (self != [MyCollection class])
		return;

	[self applyTraitFromClass: [ETCollection class]];
	[self applyTraitFromClass: [ETMutableCollection class]];
}

// Omitted initialization and deallocation methods

- (id) content
{
	return things;
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: things];
}

- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	if (index == ETUndeterminedIndex)
	{
		[things addObject: object];
	}
	else
	{
		[things insertObject: object atIndex: index];
	}
}

- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	if (index == ETUndeterminedIndex)
	{
		[things removeObject: object];
	}
	else
	{
		[things removeObjectAtIndex: index];
	}
}

@end 
</example> */
@interface ETCollectionTrait : NSObject <ETCollection>
@end

/** @group Collection Protocols

This trait implements all ETCollectionMutation protocol methods, except 
-insertObject:atIndex:hint: and -removeObject:atIndex:hint:, for which concrete 
implementations must be provided by the target class.

Any method provided by ETMutableCollectionTrait can be overriden by 
implementing the method in the target class.

For a use case example, see ETCollectionTrait. */
@interface ETMutableCollectionTrait : ETCollectionTrait <ETCollectionMutation>
@end

/* Adopted by the following Foundation classes  */

/** @group Collection Protocols */
@interface NSArray (ETCollection) <ETCollection>
+ (Class) mutableClass;
- (BOOL) isOrdered;
- (id) content;
- (NSArray *) contentArray;
@end

/** @group Collection Protocols */
@interface NSDictionary (ETCollection) <ETCollection>
+ (Class) mutableClass;
- (id) content;
- (NSArray *) contentArray;
- (NSString *) identifierAtIndex: (NSUInteger)index;
@end

/** @group Collection Protocols */
@interface NSSet (ETCollection) <ETCollection>
+ (Class) mutableClass;
- (id) content;
- (NSArray *) contentArray;
@end

/**  @group Collection Protocols

NSCountedSet is a NSMutableSet subclass and thereby inherits the collection 
protocol methods implemented in NSSet(ETCollection). */
@interface NSCountedSet (ETCollection)
+ (Class) mutableClass;
@end

/** @group Collection Protocols */
@interface NSIndexSet (ETCollection) <ETCollection>
+ (Class) mutableClass;
- (id) content;
- (NSArray *) contentArray;
- (NSEnumerator *) objectEnumerator;
@end

/** @group Collection Protocols

For NSMutableArray, -insertObject:atIndex: raises an exception when the index 
is ETUndeterminedIndex. */
@interface NSMutableArray (ETCollectionMutation) <ETCollectionMutation>
- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
@end

/** @group Collection Protocols */
@interface NSMutableDictionary (ETCollectionMutation) <ETCollectionMutation>
- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
@end

/** @group Collection Protocols */
@interface NSMutableSet (ETCollectionMutation) <ETCollectionMutation>
- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
@end


/** @group Collection Protocols */
@interface NSMutableIndexSet (ETCollectionMutation) <ETCollectionMutation>
- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint;
@end

/** @group Collection Additions */
@interface NSArray (Etoile)

- (id) firstObject;
- (NSArray *) arrayByRemovingObjectsInArray: (NSArray *)anArray;
- (NSArray *) filteredArrayUsingPredicate: (NSPredicate *)aPredicate
                          ignoringObjects: (NSSet *)ignoredObjects;

/** @taskunit Deprecated */

- (NSArray *) objectsMatchingValue: (id)value forKey: (NSString *)key;
- (id) firstObjectMatchingValue: (id)value forKey: (NSString *)key;

@end

/**
 * @group Collection Additions
 *
 * Extension to NSMutableDictionary for a common case where each key may map to
 * several values.
 */
@interface NSMutableDictionary (DictionaryOfLists)
/**
 * Adds an object for the specific key.  If there is no value for this key, it
 * is added.  If there is an existing value and it is a mutable array, then
 * the object is added to the array.  If it is not a mutable array, the
 * existing object and the new object are both added to a new array, which is
 * set for this key in the dictionary.
 */
- (void)addObject: anObject forKey: aKey;
@end
