/*
	ETCollection+HOM.m

	This module provides collection-related higher-order messaging and
	equivalent functionality for blocks.

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
#import "ETCollection.h"
#import "ETCollection+HOM.h"
#import "NSInvocation+Etoile.h"
#import "NSObject+Etoile.h"
#import "Macros.h"
#import "EtoileCompatibility.h"

// Define the maximum number of arguments a function can take. (C99 allows up to
// 127 arguments.)
#define MAX_ARGS 127

/*
 * Private protocols to collate verbose, often used protocol-combinations.
 */
@protocol ETCollectionObject <NSObject, ETCollection>
@end

@protocol ETMutableCollectionObject <ETCollectionObject, ETCollectionMutation>
@end

/*
 * Make collection classes adopt those protocols
 */
@interface NSArray (ETHOMPrivate) <ETCollectionObject>
@end

@interface NSDictionary (ETHOMPrivate) <ETCollectionObject>
@end

@interface NSSet (ETHOMPrivate) <ETCollectionObject>
@end

@interface NSIndexSet (ETHOMPrivate) <ETCollectionObject>
@end

@interface NSMutableArray (ETHOMPrivate) <ETMutableCollectionObject>
@end

@interface NSMutableDictionary (ETHOMPrivate) <ETMutableCollectionObject>
@end

@interface NSMutableSet (ETHOMPrivate) <ETMutableCollectionObject>
@end

@interface NSMutableIndexSet (ETHOMPrivate) <ETMutableCollectionObject>
@end

/*
 * Informal protocol for turning collections into arrays.
 */
@interface NSObject (ETHOMArraysFromCollections)
- (NSArray*)collectionArray;
- (NSArray*)contentsForArrayEquivalent;
@end


/*
 * Informal protocol for the block invocation methods to invoke Smalltalk and C
 * blocks transparently.
 */
@interface NSObject(ETHOMInvokeBlocks)
- (id)value: (id)anArgument;
- (id)value: (id)anArgument value: (id)anotherArgument;
@end

/*
 * The ETEachProxy wraps collection objects for the HOM code to iterate over
 * their elements if the proxy is passed as an argument.
 */
@interface ETEachProxy : NSProxy
{
	id<ETCollectionObject> collection;
	NSArray *contents;
	NSUInteger counter;
	NSUInteger maxElements;
	IMP objectAtIndex;
}
- (id)nextObjectFromContents;
@end

/* Structures */

// Structure to wrap the char array that is used as a bitfield to mark
// argument-slots that have ETEachProxies set.
typedef struct
{
	char fields[16];
} argField_t;

// A structure to encapsulate the information the recursive mapping function
// needs.
typedef struct
{
	id<ETCollection> source;
	id<ETCollectionMutation> target;
	NSMutableArray *alreadyMapped;
	id mapInfo;
	IMP elementHandler;
	SEL handlerSelector;
	NSNull *theNull;
	NSUInteger objIndex;
	BOOL modifiesSelf;
} ETMapContext;

@implementation ETEachProxy: NSProxy
- (id)initWithOriginal: (id<ETCollectionObject>)aCollection
{
	ASSIGN(collection,aCollection);
	contents = [[(NSObject*)collection collectionArray] retain];
	counter = 0;
	maxElements = [contents count];
	objectAtIndex = [contents methodForSelector: @selector(objectAtIndex:)];
	return self;
}

DEALLOC([collection release]; [contents release];);

- (id)forwardingTargetForSelector: (SEL)aSelector
{
	return collection;
}

- (BOOL)respondsToSelector: (SEL)aSelector
{
	if (aSelector == @selector(nextObjectFromContents))
	{
		return YES;
	}
	return [collection respondsToSelector: aSelector];
}

- (id)methodSignatureForSelector: (SEL)aSelector
{
	if ([collection respondsToSelector: aSelector])
	{
		return [(NSObject*)collection methodSignatureForSelector: aSelector];
	}
	return nil;
}

- (void)forwardInvocation: (NSInvocation*)anInvocation
{
	if ([collection respondsToSelector: [anInvocation selector]])
	{
		[anInvocation invokeWithTarget: collection];
	}
}

- (id)nextObjectFromContents
{
	id object = nil;
	if (counter < maxElements)
	{
		object = objectAtIndex(contents, @selector(objectAtIndex), counter);
		counter++;
	}
	else
	{
		// Reset the counter for the next;
		counter = 0;
	}
	return object;
}
@end

@implementation NSObject (ETEachHOM)
- (id)each
{
	if ([self conformsToProtocol: @protocol(ETCollection)])
	{
		return [[[ETEachProxy alloc] initWithOriginal: (id)self] autorelease];
	}
	return self;
}
@end

/*
 * Helper method to obtain a list of the argument slots in the invocation that
 * contain an ETEachProxy.
 */
static inline argField_t eachedArgumentsFromInvocation(NSInvocation *inv)
{
	NSMethodSignature *sig = [inv methodSignature];
	NSUInteger argCount = [sig numberOfArguments];
	/* 
	 * We need a char[16] to hold 128bits, since C99 allows 127 arguments and
	 * initialize to zero:
	 */
	argField_t argField;
	memset(&(argField.fields[0]),'\0',16);
	BOOL hasProxy = NO;

	/* No method arguments (only self and _cmd as invisible arguments) */
	BOOL isUnaryInvocation = (argCount < 3);

	if (isUnaryInvocation)
	{
		return argField;
	}

	for (int i = 2; i < argCount; i++)
	{
		// Consider only object arguments:
		const char *argType = [sig getArgumentTypeAtIndex: i];
		if ((0 == strcmp(@encode(id), argType))
		  || (0 == strcmp(@encode(Class), argType)))
		{
			id arg;
			[inv getArgument: &arg atIndex: i];
			if ([arg respondsToSelector: @selector(nextObjectFromContents)])
			{
				// We need to skip to the next field of the char array every 8
				// bits. The integer division/modulo operations calculate just
				// the right offset for that.
				int index = i / 8;
				argField.fields[index] = (argField.fields[index] | (1 << (i % 8)));
				hasProxy = YES;
			}
		}
	}

	if (hasProxy)
	{
		// Use the first bit as a marker to signify that the invocation has
		// proxied-arguments.
		argField.fields[0] = argField.fields[0] | 1;
	}
	return argField;
}

/* 
 * Scan the argField to finde the index of the next argument that has an
 * each-proxy set.
 */
static inline NSUInteger nextSlotIDWithEachProxy(argField_t *slots, NSUInteger slotID)
{
	while (!(slots->fields[(slotID / 8)] & (1 << (slotID % 8))) && (slotID < MAX_ARGS))
	{
		slotID++;
	}
	return slotID;
}
/*
 * Recursive map function to fill the slots in an invocation
 * that are marked with an ETEachProxy and invoke it afterwards.
 */
static void recursiveMapWithInvocationAndContext(NSInvocation *inv, // the invocation, target and arguments < slotID set
                                                 argField_t *slots, // a bitfield of the arguments that need to be replaced
                                                 NSUInteger slotID, // the slotId for the present level of recursion
                                                 ETMapContext *ctx) // the context
{
	// Scan the slots array for the next argument-slot that has a proxy.
	slotID = nextSlotIDWithEachProxy(slots, slotID);

	/*
	 * Also find the argument-slot after that. (Needed to determine whether we
	 * should fire the invocation.)
	 */
	NSUInteger nextSlotID = nextSlotIDWithEachProxy(slots, (slotID + 1));


	id eachProxy = nil;
	if (slotID < MAX_ARGS)
	{
		[inv getArgument: &eachProxy atIndex: slotID];
	}
	id theObject;
	int count = 0;
	while (nil != (theObject = [eachProxy nextObjectFromContents]))
	{
		// Set the present argument:
		[inv setArgument: &theObject atIndex: slotID];
		if (MAX_ARGS == nextSlotID)
		{
			// If there are no more arguments to be set, the invocation is
			// properly set up, otherwise there are proxies left in the
			// invocation that need to be replaced first.
			id mapped = nil;
			[inv invoke];
			[inv getReturnValue: &mapped];

			if (nil == mapped)
			{
				mapped = ctx->theNull;
			}
			if (ctx->modifiesSelf)
			{
				[ctx->alreadyMapped addObject: mapped];
			}

			// We only want to use the handler the first time we run for this
			// target element. Otherwise it might overwrite the result from the
			// previous run(s).
			BOOL isFirstRun = (0 == count);

			if ((ctx->elementHandler != NULL) && isFirstRun)
			{
				// The elementHandler is an IMP for the -placeObject:... method
				// of the collection class. Hence the first to arguments are
				// receiver and selector.
				ctx->elementHandler(ctx->source, ctx->handlerSelector, mapped,
				                    &ctx->target, [inv target], ctx->objIndex,
				                    ctx->alreadyMapped, ctx->mapInfo);
			}
			else
			{
				// Also check the count, cf. note above.
				if (ctx->modifiesSelf && isFirstRun)
				{
					[(NSMutableArray*)ctx->target replaceObjectAtIndex: ctx->objIndex
					                                        withObject: mapped];
				}
				else
				{
					[ctx->target addObject: mapped];
				}
			}
			count++;
		}
		else
		{
			recursiveMapWithInvocationAndContext(inv, slots, nextSlotID, ctx);
		}

	}
	// Before we return, we must put the proxy back into the invocation so that
	// it can be used again when the invocation is invoked again with a
	// different combination of target and arguments.
	[inv setArgument: &eachProxy atIndex: slotID];
}


/*
 * Recursively evaluating the predicate is easier because the handling of
 * adding/removing elements can be done in the caller.
 * NOTE: The results are ORed.
 */
static BOOL recursiveFilterWithInvocation(NSInvocation *inv, // The invocation, target and arguments < slotID set
                                          argField_t *slots, // A bitfield marking the argument-slots to be replaced
                                          NSUInteger slotID) // The slotId for the present level of recursion
{
	// Scan the slots array for the next slot that has a proxy. 127 marks the
	// end of the array.
	slotID = nextSlotIDWithEachProxy(slots, slotID);

	// Repeat to find the next slot (we need this to determine whether we should
	// fire the invocation.)
	NSUInteger nextSlotID = nextSlotIDWithEachProxy(slots, (slotID + 1));

	id eachProxy = nil;
	if (slotID < MAX_ARGS)
	{
		[inv getArgument: &eachProxy atIndex: slotID];
	}
	BOOL result = NO;
	id theObject;
	while (nil != (theObject = [eachProxy nextObjectFromContents]))
	{
		// Set the present argument:
		[inv setArgument: &theObject atIndex: slotID];
		if (MAX_ARGS == nextSlotID)
		{
			// Now the invocation is set up properly. (127 is no "real" slot)
			long long filterResult = (long long)NO;
			[inv invoke];
			[inv getReturnValue: &filterResult];
			result = (result || (BOOL)filterResult);
			// In theory, we could escape the loop once the we get a positive
			// result, but the application might rely on the side-effects of the
			// invocation.
		}
		else
		{
			result = (result || recursiveFilterWithInvocation(inv, slots, nextSlotID));
		}

	}
	[inv setArgument: &eachProxy atIndex: slotID];
	return result;
}
/*
 * The following functions will be used by both the ETCollectionHOM categories 
 * and the corresponding proxies.
 */
static inline void ETHOMMapCollectionWithBlockOrInvocationToTargetAsArray(
                                      id<ETCollectionObject> *aCollection,
                                                     id blockOrInvocation,
                                                            BOOL useBlock,
                  id<NSObject,ETCollection,ETCollectionMutation> *aTarget,
                                                       BOOL isArrayTarget)
{
	if ([*aCollection isEmpty])
	{
		return;
	}

	BOOL modifiesSelf = ((id*)aCollection == (id*)aTarget);
	id<NSObject,ETCollection> theCollection = *aCollection;
	id<NSObject,ETCollection,ETCollectionMutation> theTarget = *aTarget;
	NSInvocation *anInvocation = nil;
	// Initialised to get rid of spurious warning from GCC
	SEL selector = @selector(description);

	//Prefetch some stuff to avoid doing it repeatedly in the loop.

	if (NO == useBlock)
	{
		anInvocation = (NSInvocation*)blockOrInvocation;
		selector = [anInvocation selector];
	}

	SEL handlerSelector =
	 @selector(placeObject:inCollection:insteadOfObject:atIndex:havingAlreadyMapped:mapInfo:);
	IMP elementHandler = NULL;
	if ([theCollection respondsToSelector:handlerSelector]
	  && (NO == isArrayTarget))
	{
		elementHandler = [(NSObject*)theCollection methodForSelector: handlerSelector];
	}

	SEL valueSelector = @selector(value:);
	IMP invokeBlock = NULL;
	BOOL invocationHasObjectReturnType = YES;
	if (useBlock)
	{
		if ([blockOrInvocation respondsToSelector: valueSelector])
		{
			invokeBlock = [(NSObject*)blockOrInvocation methodForSelector: valueSelector];
		}
		//FIXME: Determine the return type of the block
	}
	else
	{
		// Check whether the invocation is supposed to return objects:
		const char* returnType = [[anInvocation methodSignature] methodReturnType];
		invocationHasObjectReturnType = ((0 == strcmp(@encode(id), returnType))
	                                     || (0 == strcmp(@encode(Class), returnType)));
	}
	/*
	 * For some collections (such as NSDictionary) the index of the object
	 * needs to be tracked. 
 	 */
	unsigned int objectIndex = 0;
	NSNull *nullObject = [NSNull null];
	NSArray *collectionArray = [(NSObject*)theCollection collectionArray];
	NSMutableArray *alreadyMapped = nil;
	id mapInfo = nil;
	if (modifiesSelf)
	{
		/*
		 * For collection ensuring uniqueness of elements, like
		 * NS(Mutable|Index)Set, the objects that were already mapped need to be
		 * tracked.
		 * It is only useful if a mutable collection is changed.
		 */
		alreadyMapped = [[NSMutableArray alloc] init];
		if ([theCollection respondsToSelector:@selector(mapInfo)])
		{
			mapInfo = [(id)theCollection mapInfo];
		}
	}

	// If we are using an invocation, fetch a table of the argument slots that
	// contain proxy created with -each and create a context to be passed to
	// the function that will setup and fire the invocation.
	argField_t eachedSlots;
	// Zeroing out the first byte of the field is enough to indicate that it has
	// not been filled.
	eachedSlots.fields[0] = '\0';
	ETMapContext ctx;
	if (NO == useBlock)
	{
		eachedSlots = eachedArgumentsFromInvocation(blockOrInvocation);
		ctx.source = theCollection;
		ctx.target = theTarget;
		ctx.alreadyMapped = alreadyMapped;
		ctx.mapInfo = mapInfo;
		ctx.theNull = nullObject;
		ctx.modifiesSelf = modifiesSelf;
		ctx.elementHandler = elementHandler;
		ctx.handlerSelector = handlerSelector;
		ctx.objIndex = objectIndex;
	}
	FOREACHI(collectionArray, object)
	{
		id mapped = nil;
		if (NO == useBlock)
		{
			if (NO == [object respondsToSelector: selector])
			{
				// Don't operate on this element:
				objectIndex++;
				continue;
			}
			BOOL useEachProxy = (eachedSlots.fields[0] & 1);
			if (useEachProxy)
			{
				ctx.objIndex = objectIndex;
				[anInvocation setTarget: object];
				recursiveMapWithInvocationAndContext(anInvocation, &eachedSlots,
				                                     2, &ctx);
				objectIndex++;
				continue;
			}
			else
			{
				[anInvocation invokeWithTarget: object];
				if (invocationHasObjectReturnType)
				{
					[anInvocation getReturnValue: &mapped];
				}
			}
		}
		else
		{
			mapped = invokeBlock(blockOrInvocation, valueSelector, object);
		}
		if (nil == mapped)
		{
			mapped = nullObject;
		}
		if (modifiesSelf)
		{
			[alreadyMapped addObject: mapped];
		}

		if (elementHandler != NULL)
		{
			elementHandler(theCollection, handlerSelector, mapped, aTarget,
			               object, objectIndex, alreadyMapped, mapInfo);
		}
		else
		{
			if (modifiesSelf)
			{
				[(NSMutableArray*)theTarget replaceObjectAtIndex: objectIndex
				                                      withObject: mapped];
			}
			else
			{
				[theTarget addObject: mapped];
			}
		}
		objectIndex++;
	}

	// Cleanup:
	if (modifiesSelf)
	{
		[alreadyMapped release];
	}
}

static inline void ETHOMMapCollectionWithBlockOrInvocationToTarget(
                               id<ETCollectionObject> *aCollection,
                                              id blockOrInvocation,
                                                     BOOL useBlock,
                            id<ETMutableCollectionObject> *aTarget)
{
	ETHOMMapCollectionWithBlockOrInvocationToTargetAsArray(aCollection,
	                                                       blockOrInvocation,
	                                                       useBlock,
	                                                       aTarget,
	                                                       NO);
}

static inline id ETHOMFoldCollectionWithBlockOrInvocationAndInitialValueAndInvert(
                                             id<ETCollectionObject>*aCollection,
                                                           id blockOrInvocation,
                                                                  BOOL useBlock,
                                                                id initialValue,
                                                               BOOL shallInvert)
{
	if ([*aCollection isEmpty])
	{
		return initialValue;
	}

	id accumulator = initialValue;
	NSInvocation *anInvocation = nil;
	// Initialised to get rid of spurious warning from GCC
	SEL selector = @selector(description);

	if (NO == useBlock)
	{
		anInvocation = (NSInvocation*)blockOrInvocation;
		selector = [anInvocation selector];
	}

	SEL valueSelector = @selector(value:value:);
	IMP invokeBlock = NULL;
	if (useBlock)
	{
		NSCAssert([blockOrInvocation respondsToSelector: valueSelector],
				@"Block does nto respond to the correct selector!");
		invokeBlock = [(NSObject*)blockOrInvocation methodForSelector: valueSelector];
	}

	/*
	 * For folding we can safely consider only the content as an array.
	 */
	NSArray *content = [[(NSObject*)*aCollection collectionArray] retain];
	NSEnumerator *contentEnumerator;
	if (NO == shallInvert)
	{
		contentEnumerator = [content objectEnumerator];
	}
	else
	{
		contentEnumerator = [content reverseObjectEnumerator];
	}

	FOREACHE(content, element, id, contentEnumerator)
	{
		id target;
		id argument;
		if (NO == shallInvert)
		{
			target = accumulator;
			argument = element;
		}
		else
		{
			target = element;
			argument = accumulator;
		}

		if (NO == useBlock)
		{
			if ([target respondsToSelector:selector])
			{
				[anInvocation setArgument: &argument
				                  atIndex: 2];
				[anInvocation invokeWithTarget: target];
				[anInvocation getReturnValue: &accumulator];
			}
		}
		else
		{
			accumulator = invokeBlock(blockOrInvocation, valueSelector, target, argument);
		}
	}
	[content release];
	return accumulator;
}

static inline void ETHOMFilterCollectionWithBlockOrInvocationAndTargetAndOriginalAndInvert(
                                            id<ETCollectionObject> *aCollection,
                                                           id blockOrInvocation,
                                                                  BOOL useBlock,
                                          id<ETMutableCollectionObject> *target,
                                               id<ETCollectionObject> *original,
                                                                    BOOL invert)
{
	if ([*aCollection isEmpty])
	{
		return;
	}

	id<ETCollectionObject> theCollection = (id<ETCollectionObject>)*aCollection;
	id<ETMutableCollectionObject> theTarget = (id<ETMutableCollectionObject>)*target;
	NSInvocation *anInvocation;
	SEL selector;
	argField_t eachedSlots;
	// Zeroing out the first byte of the field is enough to indicate that the
	// field has not been filled.
	eachedSlots.fields[0] = '\0';

	if (NO == useBlock)
	{
		anInvocation = (NSInvocation*)blockOrInvocation;
		selector = [anInvocation selector];
		eachedSlots = eachedArgumentsFromInvocation(blockOrInvocation);
	}

	NSArray* content = [[(NSObject*)theCollection collectionArray] retain];
	
	/*
	 * A snapshot of the object is needed at least for NSDictionary. It needs
	 * to know about the key for which the original object was set in order to
	 * remove/add objects correctly. Also other collections might rely on
	 * additional information about the original collection. Still, we don't
	 * want to bother with creating the snapshot if the collection does not
	 * implement the -placeObject... method.
	 */

	id snapshot = nil;

	SEL handlerSelector =
	   @selector(placeObject:atIndex:inCollection:basedOnFilter:withSnapshot:);
	IMP elementHandler = NULL;
	if ([theCollection respondsToSelector: handlerSelector])
	{
		elementHandler = [(NSObject*)*original methodForSelector: handlerSelector];
		if ((id)theCollection != (id)theTarget)
		{
			snapshot = *original;
		}
		else
		{
			if ([theCollection respondsToSelector: @selector(copyWithZone:)])
			{
				snapshot = [[(id<NSCopying>)*original copyWithZone: NULL] autorelease];
			}
		}
	}
	unsigned int objectIndex = 0;
	NSEnumerator *originalEnum = [[(NSObject*)*original collectionArray] objectEnumerator];
	FOREACHI(content, object)
	{
		id originalObject = [originalEnum nextObject];
		long long filterResult = (long long)NO;
		if (NO == useBlock)
		{
			if (NO == [object respondsToSelector: selector])
			{
				// Don't operate on this element:
				objectIndex++;
				continue;
			}
			BOOL usesEachProxy = (eachedSlots.fields[0] & 1);
			if (usesEachProxy)
			{
				[anInvocation setTarget: object];
				filterResult = recursiveFilterWithInvocation(anInvocation, &eachedSlots, 2);
			}
			else
			{
				[anInvocation invokeWithTarget: object];
				[anInvocation getReturnValue: &filterResult];
			}
		}
		#if __has_feature(blocks)
		else
		{
			BOOL(^theBlock)(id) = (BOOL(^)(id))blockOrInvocation;
			filterResult = (long long)theBlock(object);
		}
		#endif
		if (invert)
		{
			filterResult = !(BOOL)filterResult;
		}
		if (elementHandler != NULL)
		{
			elementHandler(*original, handlerSelector, originalObject,
			               objectIndex, target, (BOOL)filterResult, snapshot);
		}
		else
		{
			if (((id)theTarget == (id)*original) && (NO == (BOOL)filterResult))
			{
				[theTarget removeObject: originalObject];
			}
			else if (((id)theTarget!=(id)*original) && (BOOL)filterResult)
			{
				[theTarget addObject: originalObject];
			}
		}
		objectIndex++;
	}
	[content release];
}

static inline void ETHOMFilterCollectionWithBlockOrInvocationAndTargetAndInvert(
                                            id<ETCollectionObject> *aCollection,
                                                          id  blockOrInvocation,
                                                                  BOOL useBlock,
                                          id<ETMutableCollectionObject> *target,
                                                                    BOOL invert)
{
	ETHOMFilterCollectionWithBlockOrInvocationAndTargetAndOriginalAndInvert(
	                                                      aCollection,
	                                                      blockOrInvocation,
	                                                      useBlock,
	                                                      target,
	                                                      aCollection,
	                                                      invert);
}

static inline id ETHOMFilteredCollectionWithBlockOrInvocationAndInvert(
                                            id<ETCollectionObject> *aCollection,
                                                           id blockOrInvocation,
                                                                  BOOL useBlock,
                                                                    BOOL invert)
{
	id<ETMutableCollectionObject> mutableCollection = [[[[*aCollection class] mutableClass] alloc] init];
	ETHOMFilterCollectionWithBlockOrInvocationAndTargetAndInvert(aCollection,
	                                                       blockOrInvocation,
	                                                                useBlock,
	                                                      &mutableCollection,
	                                                                  invert);
	return [mutableCollection autorelease];
}

static inline void ETHOMFilterMutableCollectionWithBlockOrInvocationAndInvert(
                                     id<ETMutableCollectionObject> *aCollection,
                                                           id blockOrInvocation,
                                                                  BOOL useBlock,
                                                                    BOOL invert)
{
	ETHOMFilterCollectionWithBlockOrInvocationAndTargetAndOriginalAndInvert(
	                                                             aCollection,
	                                                       blockOrInvocation,
	                                                                useBlock,
	                                                             aCollection,
	                                                             aCollection,
                                                                      invert);
}


static inline void ETHOMZipCollectionsWithBlockOrInvocationAndTarget(
                          id<NSObject,ETCollection> *firstCollection,
                         id<NSObject,ETCollection> *secondCollection,
                                                id blockOrInvocation,
                                                       BOOL useBlock,
              id<NSObject,ETCollection,ETCollectionMutation> *target)
{
	if ([*firstCollection isEmpty])
	{
		return;
	}

	BOOL modifiesSelf = ((id*)firstCollection == (id*)target);
	NSInvocation *invocation = nil;
	// Initialised to get rid of spurious warning from GCC
	SEL selector = @selector(description);
	NSArray *contentsFirst = [(NSObject*)*firstCollection collectionArray];
	NSArray *contentsSecond = [(NSObject*)*secondCollection collectionArray];
	if (NO == useBlock)
	{
		invocation = (NSInvocation*)blockOrInvocation;
		selector = [invocation selector];
	}

	SEL handlerSelector =
	 @selector(placeObject:inCollection:insteadOfObject:atIndex:havingAlreadyMapped:mapInfo:);
	IMP elementHandler = NULL;
	id mapInfo = nil;
	if ([*firstCollection respondsToSelector: handlerSelector])
	{
		elementHandler = [(NSObject*)*firstCollection methodForSelector: handlerSelector];
	}

	SEL valueSelector = @selector(value:value:);
	IMP invokeBlock = NULL;
	if (useBlock)
	{
		NSCAssert([blockOrInvocation respondsToSelector: valueSelector],
				@"Block does nto respond to the correct selector!");
		invokeBlock = [(NSObject*)blockOrInvocation methodForSelector: valueSelector];
	}

	NSMutableArray *alreadyMapped = nil;
	if (modifiesSelf)
	{
		alreadyMapped = [[NSMutableArray alloc] init];
		if ([*firstCollection respondsToSelector: @selector(mapInfo)])
		{
			mapInfo = [(id)*firstCollection mapInfo];
		}
	}

	NSUInteger objectIndex = 0;
	NSUInteger objectMax = MIN([contentsFirst count], [contentsSecond count]);
	NSNull *nullObject = [NSNull null];

	FOREACHI(contentsFirst, firstObject)
	{
		if (objectIndex >= objectMax)
		{
			break;
		}
		id secondObject = [contentsSecond objectAtIndex: objectIndex];
		id mapped = nil;
		if (NO == useBlock)
		{
			if (NO == [firstObject respondsToSelector: selector])
			{
				objectIndex++;
				continue;
			}

			[invocation setArgument: &secondObject
			                atIndex: 2];
			[invocation invokeWithTarget: firstObject];
			[invocation getReturnValue: &mapped];
		}
		else
		{
			mapped = invokeBlock(blockOrInvocation, valueSelector, firstObject,
			                     secondObject);
		}

		if (nil == mapped)
		{
			mapped = nullObject;
		}

		if (modifiesSelf)
		{
			[alreadyMapped addObject: mapped];
		}

		if (elementHandler != NULL)
		{
			elementHandler(*firstCollection, handlerSelector, mapped, target,
			               firstObject, objectIndex, alreadyMapped, mapInfo);
		}
		else
		{
			if (modifiesSelf)
			{
				[(NSMutableArray*)*target replaceObjectAtIndex: objectIndex
				                                    withObject: mapped];
			}
			else
			{
				[*target addObject: mapped];
			}
		}
		objectIndex++;
	}

	if (modifiesSelf)
	{
		[alreadyMapped release];
	}
}

/*
 * Proxies for higher-order messaging via forwardInvocation.
 */
@interface ETCollectionHOMProxy: NSProxy
{
	id<ETCollectionObject> collection;
}
@end

@interface ETCollectionMapProxy: ETCollectionHOMProxy
@end

@interface ETCollectionMutationMapProxy: ETCollectionHOMProxy
@end

@interface ETCollectionFoldProxy: ETCollectionHOMProxy
{
	BOOL inverse;
}
@end

@interface ETCollectionMutationFilterProxy: ETCollectionHOMProxy
{
	// Stores a reference to the original collection, even if the actual filter
	// operates on a modified one.
	id<ETMutableCollectionObject> originalCollection;
	BOOL invert;

}
@end

@interface ETCollectionZipProxy: ETCollectionHOMProxy
{
	id<ETCollectionObject> secondCollection;
}
@end


@interface ETCollectionMutationZipProxy: ETCollectionZipProxy
@end

@implementation ETCollectionHOMProxy
- (id)initWithCollection: (id<ETCollectionObject>)aCollection
{
	collection = [aCollection retain];
	return self;
}

- (BOOL)respondsToSelector: (SEL)aSelector
{
	if ([collection isEmpty])
	{
		return YES;
	}

	NSEnumerator *collectionEnumerator = [(NSArray*)collection objectEnumerator];
	FOREACHE(collection, object, id, collectionEnumerator)
	{
		if ([object respondsToSelector: aSelector])
		{
			return YES;
		}
	}
	return [NSObject instancesRespondToSelector: aSelector];
}

- (NSMethodSignature*)primitiveMethodSignatureForSelector: (SEL)aSelector
{
	return [NSObject instanceMethodSignatureForSelector: aSelector];
}

/* You can override this method to return a custom method signature as 
ETCollectionMutationFilterProxy does.
You can call -primitiveMethodSignatureForSelector: in the overriden version, but 
not -[super methodSignatureForSelector:]. */
- (NSMethodSignature*)methodSignatureForEmptyCollection
{
	/* 
	 * Returns any arbitrary NSObject selector whose return type is id.
	 */
	return [NSObject instanceMethodSignatureForSelector: @selector(self)];
}

- (id)methodSignatureForSelector: (SEL)aSelector
{
	if ([collection isEmpty])
	{
		return [self methodSignatureForEmptyCollection];
	}

	/*
	 * The collection is cast to NSArray because even though all classes
	 * adopting ETCollection provide -objectEnumerator this is not declared.
	 * (See ETCollection.h)
	 */
	NSEnumerator *collectionEnumerator = [(NSArray*)collection objectEnumerator];
	FOREACHE(collection, object, id, collectionEnumerator)
	{
		if ([object respondsToSelector:aSelector])
		{
			return [object methodSignatureForSelector:aSelector];
		}
	}
	return [NSObject instanceMethodSignatureForSelector:aSelector];
}

- (Class)class
{
	NSInvocation *inv = [NSInvocation invocationWithTarget: self selector: _cmd arguments: nil];
	Class retValue = Nil;

	[self forwardInvocation: inv];
	[inv getReturnValue: &retValue];
	return retValue;
}

DEALLOC(
	[collection release];
)
@end

@implementation ETCollectionMapProxy
- (void)forwardInvocation: (NSInvocation*)anInvocation
{
	Class mutableClass = [[collection class] mutableClass];
	id<ETMutableCollectionObject> mappedCollection = [[[mutableClass alloc] init] autorelease];
	ETHOMMapCollectionWithBlockOrInvocationToTarget(
	                                    (id<ETCollectionObject>*) &collection,
	                                                             anInvocation,
	                                                                       NO,
	                                                        &mappedCollection);
	[anInvocation setReturnValue: &mappedCollection];
}
@end

@implementation ETCollectionMutationMapProxy
- (void)forwardInvocation: (NSInvocation*)anInvocation
{

	ETHOMMapCollectionWithBlockOrInvocationToTarget(
	                                    (id<ETCollectionObject>*)&collection,
	                                                            anInvocation,
	                                                                      NO,
	                             (id<ETMutableCollectionObject>*)&collection);
	//Actually, we don't care for the return value.
	[anInvocation setReturnValue:&collection];
}
@end


@implementation ETCollectionFoldProxy
- (id)initWithCollection: (id<ETCollectionObject>)aCollection 
              forInverse: (BOOL)shallInvert
{
	
	if (nil == (self = [super initWithCollection: aCollection]))
	{
		return nil;
	}
	inverse = shallInvert;
	return self;
}

- (void)forwardInvocation: (NSInvocation*)anInvocation
{

	id initialValue = nil;
	if ([collection isEmpty] == NO)
	{
		[anInvocation getArgument: &initialValue atIndex: 2];
	}
	id foldedValue =
	ETHOMFoldCollectionWithBlockOrInvocationAndInitialValueAndInvert(&collection,
	                                                                 anInvocation,
	                                                                 NO,
	                                                                 initialValue,
                                                                     inverse);
	[anInvocation setReturnValue:&foldedValue];
}
@end

@implementation ETCollectionMutationFilterProxy
- (id)initWithCollection: (id<ETCollectionObject>) aCollection
             andOriginal: (id<ETCollectionObject>) theOriginal
               andInvert: (BOOL)shallInvert
{
	if (nil == (self = [super initWithCollection: aCollection]))
	{
		return nil;
	}
	originalCollection = [theOriginal retain];
	invert = shallInvert;
	return self;
}

- (id)initWithCollection: (id<ETCollectionObject>) aCollection
               andInvert: (BOOL)aFlag
{
	self = [self initWithCollection: aCollection
	                    andOriginal: aCollection
	                      andInvert: aFlag];
	return self;
}
- (id)initWithCollection: (id<ETCollectionObject>) aCollection
{
	self = [self initWithCollection: aCollection
	                    andOriginal: aCollection
	                      andInvert: NO];
	return self;
}

- (id)initWithCollection: (id<ETCollectionObject>) aCollection
             andOriginal: (id<ETCollectionObject>) theOriginal
{
	self = [self initWithCollection: aCollection
	                    andOriginal: theOriginal
	                      andInvert: NO];
	return self;
}

- (NSMethodSignature*)methodSignatureForEmptyCollection
{
	/* 
	 * Returns any arbitrary NSObject selector whose return type is BOOL.
	 *
	 * When the collection is empty, if we have two chained messages like 
	 * [[[collection filter] name] isEqualToString: @"blabla"], the proxy cannot 
	 * infer the return types of -name and -isEqualToString: (not exactly true 
	 * in the GNU runtime case which supports typed selectors). Hence we cannot 
	 * know whether we have one or two messages in arguments. 
	 * The solution is to pretend we have only one message whose signature is 
	 * -(BOOL)xxx and use NO as the return value. 
	 * Because NO is the same than nil, any second message is discarded.
	 *
	 * An alternative which doesn't require -primitiveMethodSignatureForSelector 
	 * would be to pretend we have two messages. With [[x filter] isXYZ], -isXYZ 
	 * would be treated as -(id)isXYZ. A secondary proxy would be created and 
	 * its adress put into the BOOL return value. This secondary proxy would 
	 * never receive a message and the returned boolean would be random.
	 */
	return [super primitiveMethodSignatureForSelector: @selector(isProxy)];
}

- (void)forwardInvocation: (NSInvocation*)anInvocation
{
	const char *returnType = [[anInvocation methodSignature] methodReturnType];
	if (0 == strcmp(@encode(BOOL), returnType))
	{
		ETHOMFilterCollectionWithBlockOrInvocationAndTargetAndOriginalAndInvert(
		                                                       (id*)&collection,
		                                                           anInvocation,
		                                                                     NO,
		                                               (id*)&originalCollection,
		                                               (id*)&originalCollection,
		                                                                 invert);
		BOOL result = NO;
		[anInvocation setReturnValue: &result];
	}
	else if ((0 == strcmp(@encode(id), returnType))
	  || (0 == strcmp(@encode(Class), returnType)))
	{
		id<ETMutableCollectionObject> nextCollection = [NSMutableArray array];
		ETHOMMapCollectionWithBlockOrInvocationToTargetAsArray((id*)&collection,
		                                                          anInvocation,
		                                                                    NO,
		                       (id<ETMutableCollectionObject>*)&nextCollection,
		                                                                  YES);
		id nextProxy = [[[ETCollectionMutationFilterProxy alloc]
		                              initWithCollection: nextCollection
		                                     andOriginal: originalCollection
		                                       andInvert: invert] autorelease];
		[anInvocation setReturnValue: &nextProxy];
	}
	else
	{
		[super forwardInvocation: anInvocation];
	}
}

DEALLOC(
	[originalCollection release];
)
@end

@implementation ETCollectionZipProxy
- (id)initWithCollection: (id<ETCollectionObject>)aCollection
           andCollection: (id<ETCollectionObject>)anotherCollection
{
	if (nil == (self = [super initWithCollection: aCollection]))
	{
		return nil;
	}
	secondCollection = [anotherCollection retain];
	return self;
}

- (void)forwardInvocation: (NSInvocation*)anInvocation
{
	Class mutableClass = [[collection class] mutableClass];
	id<ETMutableCollectionObject> result = [[[mutableClass alloc] init] autorelease];
	ETHOMZipCollectionsWithBlockOrInvocationAndTarget(&collection,
	                                                  &secondCollection,
	                                                  anInvocation,
	                                                  NO,
	                                                  &result);
	[anInvocation setReturnValue: &result];
}

DEALLOC(
	[secondCollection release];
)
@end

@implementation ETCollectionMutationZipProxy
- (void)forwardInvocation: (NSInvocation*)anInvocation
{
	ETHOMZipCollectionsWithBlockOrInvocationAndTarget(&collection,
	                                            &secondCollection,
	                                                 anInvocation,
	                                                           NO,
	                                             (id*)&collection);
	[anInvocation setReturnValue: &collection];
}
@end

@implementation NSArray (ETCollectionHOM)
#include "ETCollection+HOMMethods.m"
@end

@implementation NSDictionary (ETCollectionHOM)
- (NSArray*)mapInfo
{
	return [self allKeys];
}

- (void)placeObject: (id)mappedObject
       inCollection: (id<ETCollectionMutation>*)aTarget
    insteadOfObject: (id)originalObject
            atIndex: (NSUInteger)index
havingAlreadyMapped: (NSArray*)alreadyMapped
            mapInfo: (id)mapInfo
{
	//FIXME: May break if -identifierAtIndex: does not return keys in order.
	[(NSMutableDictionary*)*aTarget setObject: mappedObject
	                                   forKey: [self identifierAtIndex: index]];
}
- (void)placeObject: (id)anObject
            atIndex: (NSUInteger)index
       inCollection: (id<ETCollectionMutation>*)aTarget
      basedOnFilter: (BOOL)shallInclude
       withSnapshot: (id)snapshot
{
	NSString *key = [(NSDictionary*)snapshot identifierAtIndex: index];
	if (((id)self == (id)*aTarget) && (NO == shallInclude))
	{
		[(NSMutableDictionary*)*aTarget removeObjectForKey: key];
	}
	else if (((id)self != (id)*aTarget) && shallInclude)
	{
		[(NSMutableDictionary*)*aTarget setObject: anObject forKey: key];
	}
}
#include "ETCollection+HOMMethods.m"
@end

@implementation NSSet (ETCollectionHOM)
#include "ETCollection+HOMMethods.m"
@end

@implementation NSIndexSet (ETCollectionHOM)
#include "ETCollection+HOMMethods.m"
@end

@implementation NSMutableArray (ETCollectionHOM)
- (void)placeObject: (id)mappedObject
       inCollection: (id<ETCollectionMutation>*)aTarget
    insteadOfObject: (id)originalObject
            atIndex: (NSUInteger)index
havingAlreadyMapped: (NSArray*)alreadyMapped
            mapInfo: (id)mapInfo
{
	if ((id)self == (id)*aTarget)
	{
		[(NSMutableArray*)*aTarget replaceObjectAtIndex: index
		                                     withObject: mappedObject];
	}
	else
	{
		[*aTarget addObject: mappedObject];
	}
}
#include "ETCollectionMutation+HOMMethods.m"
@end

@implementation NSMutableDictionary (ETCollectionHOM)
- (void)placeObject: (id)mappedObject
       inCollection: (id<ETCollectionMutation>*)aTarget
    insteadOfObject: (id)originalObject
            atIndex: (NSUInteger)index
havingAlreadyMapped: (NSArray*)alreadyMapped
            mapInfo: (id)mapInfo
{
	id key = nil;
	if (*aTarget == self)
	{
		key = [(NSArray*)mapInfo objectAtIndex: index];
	}
	else
	{
		key = [self identifierAtIndex: index];
	}
	[(NSMutableDictionary*)*aTarget setObject: mappedObject
	                                   forKey: key];
}
#include "ETCollectionMutation+HOMMethods.m"
@end

@implementation NSMutableSet (ETCollectionHOM)
- (void)placeObject: (id)mappedObject
       inCollection: (id<ETCollectionMutation>*)aTarget
    insteadOfObject: (id)originalObject
            atIndex: (NSUInteger)index
havingAlreadyMapped: (NSArray*)alreadyMapped
            mapInfo: (id)mapInfo
{
	if (((id)self == (id)*aTarget) 
	 && (NO == [alreadyMapped containsObject: originalObject]))
	{
		[*aTarget removeObject: originalObject];
	}
	[*aTarget addObject: mappedObject];
}
#include "ETCollectionMutation+HOMMethods.m"
@end

/*
 * NSCountedSet does not implement the HOM-methods itself, but it does need to
 * override the -placeObject:... method of its superclass. 
 */
@interface NSCountedSet (ETCollectionMapHandler)
@end

@implementation NSCountedSet (ETCOllectionMapHandler)
- (NSArray*)contentsForArrayEquivalent
{
	NSArray *distinctObjects = [self allObjects];
	NSMutableArray *result = [NSMutableArray array];
	FOREACHI(distinctObjects,object)
	{
		for(int i = 0; i < [self countForObject:object]; i++)
		{
			[result addObject: object];
		}
	}
	return result;
}

// NOTE: These methods do nothing more than the default implementation. But they
// are needed to override the implementation in NSMutableSet.
- (void)placeObject: (id)mappedObject
       inCollection: (id<ETCollectionMutation>*)aTarget
    insteadOfObject: (id)originalObject
            atIndex: (NSUInteger)index
havingAlreadyMapped: (NSArray*)alreadyMapped
            mapInfo: (id)mapInfo
{
	if ((id)self == (id)*aTarget)
	{
		[*aTarget removeObject: originalObject];
	}
	[*aTarget addObject: mappedObject];
}

@end

@implementation NSMutableIndexSet (ETCollectionHOM)
- (void)placeObject: (id)mappedObject
       inCollection: (id<ETCollectionMutation>*)aTarget
    insteadOfObject: (id)originalObject
            atIndex: (NSUInteger)index
havingAlreadyMapped: (NSArray*)alreadyMapped
            mapInfo: (id)mapInfo
{
	if (((id)self == (id)*aTarget) 
	 && (NO == [alreadyMapped containsObject: originalObject]))
	{
		[*aTarget removeObject: originalObject];
	}
	[*aTarget addObject: mappedObject];
}

#include "ETCollectionMutation+HOMMethods.m"
@end
