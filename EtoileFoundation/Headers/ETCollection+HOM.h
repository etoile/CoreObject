/*
	ETCollection+HOM.h

	Higher-order messaging additions to ETCollection 

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

// Compatibility with non-clang compilers:
#ifndef __has_feature
#	define __has_feature(x) 0
#endif

#import <Foundation/Foundation.h>

@interface NSObject (ETEachHOM)
/**
 * If the receiver conforms to the ETCollection protocol, this method returns a
 * proxy that will let -map and -filter methods iterate over the contents of the
 * collection when it is used as an argument to a message. This way,
 * <code>[[people map] sendMail: [messages each]];</code> will cause the
 * -sendMail: message to be executed once with every combination of elements
 * from the <code>people</code> and the <code>messages</code> collection.
 *
 * Note 1: It is only possible to use an proxy object created with -each if it
 * is passed as an argument to a message that is send to a higher-order
 * messaging proxy created by -filter, -map, -filteredCollection or
 * -mappedCollection. Doing <code>[aCollection addObject: [things each]]</code>
 * won't do anything.
 *
 * Note 2: If an each proxy is passed to a message used as a filter predicate,
 * it suffices that the predicate evaluates to YES for one element of the
 * argument-collection. If a collection <code>A</code> contains "foo" and "bar"
 * and collection <code>B</code> contains "BAR" and "bar", after <code>[[A
 * filter] isEqualToString: [B each]];</code>, <code>A</code> will still contain
 * "bar" (but not "BAR"), since one of the elements of <code>B</code> matched
 * "bar".
 */
- (id)each;
@end

@protocol ETCollection, ETCollectionMutation;

@protocol ETCollectionHOM

/**
 * Returns a proxy object on which methods can be called. These methods will
 * cause a collection to be returned containing the elements of the original
 * collection mapped by the method call.
 *
 * Example: <code>addresses = [[people mappedCollection] address];</code> will
 * cause <code>addresses</code> to be a collection created by sending
 * <code>-address</code> to every element in <code>people</code>.
 */
- (id)mappedCollection;

/**
 * Returns a proxy object that can be used to perform a left fold on the
 * collection. The value of the first argument of any method used as a folding
 * method is taken to be the initial value of the accumulator, with the
 * accumulator being used as the receiver of the folding method.
 *
 * Example: <code>total = [[salaries leftFold] addAmount: nullSalary];</code>
 * will compute <code>total</code> of all elements in <code>salaries</code> by
 * using the <code>-addAmount:</code> message.
 */
- (id)leftFold;

/**
 * Returns a proxy object that can be used to perform a right fold on the
 * collection. The value of the first argument of any method used as a folding
 * method is taken to be the initial value of the accumulator, with the
 * accumulator being used as the argument of the folding method.
 *
 * Example: If <code>characters</code> is an ordered collection containing "x",
 * "y" and "z" (in that order), <code>[[characters rightFold]
 * stringByAppendingString: @": end"];</code> will produce "xyz: end".
 */
- (id)rightFold;

/**
 * Returns a proxy object the will use the next message received to coalesce the
 * receiver and aCollection into one collection by sending the message to every
 * element of the receiver with the corresponding element of the second
 * collection as an argument. The first argument (after the implicit receiver
 * and selector arguments) of the message is thus ignored.
 * The operation will stop at the end of the shorter collection.
 *
 * Example: If collection <code>A</code> contains "foo" and "FOO", and
 * collection <code>B</code> "bar" and "BAR", <code>[[A
 * zippedCollectionWithCollection: B] stringByAppendingString: nil];</code> will
 * produce a collection containing "foobar" and "FOOBAR".
 */
- (id)zippedCollectionWithCollection: (id<NSObject,ETCollection>)aCollection;

/**
 * Returns a collection with each element of the original collection mapped by
 * applying aBlock where aBlock takes one argument of type id and returns id.
 */
- (id)mappedCollectionWithBlock: (id)aBlock;

/**
 * Folds the collection by applying aBlock consecutively with the accumulator as
 * the first and each element as the second argument of the block.
 */
- (id)leftFoldWithInitialValue: (id)initialValue
                     intoBlock: (id)aBlock;

/**
 * Folds the collection by applying aBlock consecutively with the accumulator as
 * the second and each element (beginning with the last) as the first argument
 * of the block.
 */
- (id)rightFoldWithInitialValue: (id)initialValue
                      intoBlock: (id)aBlock;

/**
 * Coalesces the receiver and the collection named by aCollection into one
 * collection by applying aBlock (where aBlock takes two arguments of type id)
 * to all element-pairs built from the receiver and aCollection. The operation
 * will stop at the end of the shorter collection.
 *
 * Example: For A={a,b} and B={c,d,e} <code>C = [A
 * zippedCollectionWithCollection: B andBlock: ^ NSString* (NSString *foo,
 * NSString *bar) {return [foo stringByAppendingString: bar];}];</code> will
 * result in C={ac,bd}.
 */
- (id)zippedCollectionWithCollection: (id<NSObject,ETCollection>)aCollection
                            andBlock: (id)aBlock;

#if __has_feature(blocks)
/**
 * Returns a collection containing all elements of the original collection that
 * respond with YES to aBlock.
 */
- (id)filteredCollectionWithBlock: (BOOL(^)(id))aBlock;

/**
 * Returns a collection containing all elements of the original collection that
 * respond with NO to aBlock.
 */
- (id)filteredOutCollectionWithBlock: (BOOL(^)(id))aBlock;
#endif
@end

@protocol ETCollectionMutationHOM
/**
 * Returns a proxy object on which methods can be called. These methods will
 * cause each element in the collection to be replaced with the return value of
 * the method call.
 */
- (id)map;

/**
 * Returns a proxy object on which methods with return type BOOL can be called.
 * Only elements that respond with YES to the method call will remain in the
 * collection. If there are any object returning messages sent to the proxy
 * before the predicate, these messages will be applied to the elements in the
 * collection before the test is performed. It is thus possible to filter a
 * collection based on attributes of an object:
 * <code>[[[persons filter] firstName] isEqual: @"Alice"]</code>
 *
 * The returned boolean that corresponds to the last message is undetermined.
 * For example, the code below is meaningless:
 * <code>if ([[[persons filter] firstName] isEqual: @"Alice"]) doSomething;</code>
 */
- (id)filter;

/**
 * Filters a collection the same way -filter does, but only includes objects
 * that respond with NO to the predicate.
 */
- (id)filterOut;

/**
 * Returns a proxy object which will coalesce the collection named by
 * aCollection into the first collection by sending all messages sent to the
 * proxy to the elements of the receiver with the corresponding element of
 * aCollection as an argument. The first argument of the message (after the
 * implicit receiver and selector arguments) is thus ignored. The operation will
 * stop at the end of the shorter collection.
 */
- (id)zipWithCollection: (id<NSObject,ETCollection>)aCollection;

/**
 * Replaces each element in the collection with the result of applying aBlock to
 * it. The blocks takes one argument of type id.
 */
- (void)mapWithBlock: (id)aBlock;

/**
 * Coalesces the second collection into the first by applying aBlock (where
 * aBlock takes two arguments of type id) to all element pairs. Processing will
 * stop at the end of the shorter collection.
 */
- (void)zipWithCollection: (id<NSObject,ETCollection>)aCollection
                 andBlock: (id)aBlock;

#if __has_feature(blocks)
/**
 * Removes all elements from the collection for which the aBlock does not return
 * YES.
 */
- (void)filterWithBlock: (BOOL(^)(id))aBlock;

/**
 * Removes all elements from the collection for which the aBlock does not return
 * NO.
 */
- (void)filterOutWithBlock: (BOOL(^)(id))aBlock;
#endif
@end

/**
 * The ETCollectionHOMMapIntegration protocol defines a hook that collections can
 * use to tie into higher-order messaging if they need special treatment of
 * their elements.
 */
@protocol ETCollectionHOMMapIntegration

/**
 * This method will be called by the map- and zip-functions. If a class
 * implements a <code>-mapInfo</code> method the return value of that method
 * will be passed here. It can be used to pass information about the original
 * state of the collection.
 */
- (void)placeObject: (id)mappedObject
       inCollection: (id<ETCollectionMutation>*)aTarget
    insteadOfObject: (id)originalObject
            atIndex: (NSUInteger)index
havingAlreadyMapped: (NSArray*)alreadyMapped
            mapInfo: (id)mapInfo;
@end

/**
 * The ETCollectionHOMFilterIntegration protocol defines a hook that collections can
 * use to tie into higher-order messaging if they need special treatment of
 * their elements.
 */
@protocol ETCollectionHOMFilterIntegration
/**
 * This method will be called by the filter proxy.
 */
- (void)placeObject: (id)anObject
            atIndex: (NSUInteger)index
       inCollection: (id<ETCollectionMutation>*)aTarget
      basedOnFilter: (BOOL)shallInclude
       withSnapshot: (id)snapshot;
@end

@protocol ETCollectionHOMIntegration <ETCollectionHOMMapIntegration,ETCollectionHOMFilterIntegration>
@end

@interface NSObject (ETCollectionHOMIntegrationInformalProtocol)
/**
 * Implement this method if your collection class needs special treatment of its
 * elements for higher-order messaging.
 */
- (id)mapInfo;
@end

@interface NSArray (ETCollectionHOM) <ETCollectionHOM>
@end

@interface NSDictionary (ETCollectionHOM) <ETCollectionHOM,ETCollectionHOMIntegration>
/**
 * Helper method for map-HOM integration. Returns the keys in the dictionary.
 */
- (NSArray*)mapInfo;
@end

@interface NSSet (ETCollectionHOM) <ETCollectionHOM>
@end

@interface NSIndexSet (ETCollectionHOM) <ETCollectionHOM> 
@end

@interface NSMutableArray (ETCollectionHOM) <ETCollectionMutationHOM,ETCollectionHOMMapIntegration>
@end

@interface NSMutableDictionary (ETCollectionHOM) <ETCollectionMutationHOM>
@end

@interface NSMutableSet (ETCollectionHOM) <ETCollectionMutationHOM, ETCollectionHOMMapIntegration>
@end

@interface NSMutableIndexSet (ETCollectionHOM) <ETCollectionMutationHOM, ETCollectionHOMMapIntegration>
@end
