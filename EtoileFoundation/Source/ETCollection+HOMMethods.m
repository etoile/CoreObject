/*
	ETCollection+HOMMethods.m

	Reusable methods for higher-order messaging on collection classes.

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

/*
 * NOTE:
 * This file is included by ETCollection+HOM.m to provide reusable methods for
 * higher-order messaging on collection classes.
 */

- (id)mappedCollection
{
	return [[[ETCollectionMapProxy alloc] initWithCollection: self]
	                                                    autorelease];
}
- (id)leftFold
{
	return [[[ETCollectionFoldProxy alloc] initWithCollection: self
	                                               forInverse: NO]
	                                                   autorelease];
}

- (id)rightFold
{
	return [[[ETCollectionFoldProxy alloc] initWithCollection: self
	                                               forInverse: YES]
	                                                    autorelease];
}

- (id)zippedCollectionWithCollection: (id<NSObject,ETCollection>)aCollection
{
	return [[[ETCollectionZipProxy alloc] initWithCollection: self
	                                           andCollection: (id)aCollection]
	                                                              autorelease];
}

/**
 * Helper method to create arrays from collections.
 */
- (NSArray*)collectionArray
{
	if ([self respondsToSelector: @selector(contentsForArrayEquivalent)])
	{
		return [self contentsForArrayEquivalent];
	}
	return [self contentArray];
}

- (id)mappedCollectionWithBlock: (id)aBlock
{
	id<ETMutableCollectionObject> mappedCollection = [[[[self class] mutableClass] alloc] init];
	ETHOMMapCollectionWithBlockOrInvocationToTarget(
	                                            (id<ETCollectionObject>*) &self,
	                                                                      aBlock,
	                                                                         YES,
	                                                          &mappedCollection);
	return [mappedCollection autorelease];
}

- (id)leftFoldWithInitialValue: (id)initialValue
                     intoBlock: (id)aBlock
{
	return ETHOMFoldCollectionWithBlockOrInvocationAndInitialValueAndInvert(
	                            &self, aBlock, YES, initialValue, NO);
}

- (id)rightFoldWithInitialValue: (id)initialValue
                      intoBlock: (id)aBlock
{
	return ETHOMFoldCollectionWithBlockOrInvocationAndInitialValueAndInvert(
	                            &self, aBlock, YES, initialValue, YES);
}

- (id)zippedCollectionWithCollection: (id<NSObject,ETCollection>)aCollection
                            andBlock: (id)aBlock
{
	id<NSObject,ETCollection,ETCollectionMutation> target = [[[[[(id)self class] mutableClass] alloc] init] autorelease];
	ETHOMZipCollectionsWithBlockOrInvocationAndTarget(&self,
	                                                  &aCollection,
	                                                  aBlock,
	                                                  YES,
	                                                  &target);
	return target;
}

#if __has_feature(blocks)
- (id)filteredCollectionWithBlock: (BOOL(^)(id))aBlock
                        andInvert: (BOOL)invert
{
	return ETHOMFilteredCollectionWithBlockOrInvocationAndInvert(&self, aBlock, YES, invert);
}
- (id)filteredCollectionWithBlock: (BOOL(^)(id))aBlock
{
	return [self filteredCollectionWithBlock: aBlock
	                               andInvert: NO];
}

- (id)filteredOutCollectionWithBlock: (BOOL(^)(id))aBlock
{
	return [self filteredCollectionWithBlock: aBlock
	                               andInvert: YES];
}
#endif
