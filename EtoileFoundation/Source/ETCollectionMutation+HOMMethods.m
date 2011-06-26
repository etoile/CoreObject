/*
	ETCollectionMutation+HOMMethods.m

	Reusable methods for higher-order messaging on mutable collection classes.

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
 * higher-order messaging on mutable collections.
 */

- (id)map
{
	return [[[ETCollectionMutationMapProxy alloc] initWithCollection: self]
	                                                           autorelease];
}

- (id)filter
{
	return [[[ETCollectionMutationFilterProxy alloc] initWithCollection: self] autorelease];
}

- (id)filterOut
{
	return [[[ETCollectionMutationFilterProxy alloc] initWithCollection: self
	                                                          andInvert: YES] autorelease];
}
- (id)zipWithCollection: (id<NSObject,ETCollection>)aCollection
{
	return [[[ETCollectionMutationZipProxy alloc] initWithCollection: self
	                                                   andCollection: (id)aCollection] autorelease];
}

- (void)mapWithBlock: (id)aBlock
{
	ETHOMMapCollectionWithBlockOrInvocationToTarget(
	                                         (id<ETCollectionObject>*) &self,
	                                                                  aBlock,
	                                                                     YES,
	                                 (id<ETMutableCollectionObject>*) &self);
}

- (void)zipWithCollection: (id<NSObject,ETCollection>)aCollection
                 andBlock: (id)aBlock
{
	ETHOMZipCollectionsWithBlockOrInvocationAndTarget(&self,&aCollection,
	                                                  aBlock,YES,
	                                                  &self);
}

#if __has_feature(blocks)
- (void)filterWithBlock: (BOOL(^)(id))aBlock
              andInvert: (BOOL)invert
{
	ETHOMFilterMutableCollectionWithBlockOrInvocationAndInvert(&self,aBlock,YES,invert);
}

- (void)filterWithBlock: (BOOL(^)(id))aBlock
{
	[self filterWithBlock: aBlock andInvert: NO];
}

- (void)filterOutWithBlock: (BOOL(^)(id))aBlock
{
	[self filterWithBlock: aBlock andInvert: YES];
}
#endif
