#include "LCFieldInfo.h"
#include "GNUstep.h"

/**
* Copyright 2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@implementation LCFieldInfo

- (id) initWithName: (NSString *) na
          isIndexed: (BOOL) tk
             number: (int) nu
    storeTermVector: (BOOL) tv
    storePositionWithTermVector: (BOOL) pos
    storeOffsetWithTermVector: (BOOL) off
    omitNorms: (BOOL) ons
{
	self = [self init];
	ASSIGN(name, na);
	isIndexed = tk;
	number = nu;
	storeTermVector = tv;
	storePositionWithTermVector = pos;
	storeOffsetWithTermVector = off;
	omitNorms = ons;
	return self;
}

- (void) dealloc
{
	DESTROY(name);
	[super dealloc];
}

- (NSString *) name
{
	return name;
}

- (BOOL) isIndexed
{
	return isIndexed;
}

- (BOOL) isTermVectorStored
{
	return storeTermVector;
}

- (BOOL) isOffsetWithTermVectorStored
{
	return storeOffsetWithTermVector;
}

- (BOOL) isPositionWithTermVectorStored
{
	return storePositionWithTermVector;
}

- (int) number
{
	return number;
}

- (void) setIndexed: (BOOL) b
{
	isIndexed = b;
}

- (void) setTermVectorStored: (BOOL) b
{
	storeTermVector = b;
}

- (void) setPositionWithTermVectorStored: (BOOL) b
{
	storePositionWithTermVector = b;
}

- (void) setOffsetWithTermVectorStored: (BOOL) b
{
	storeOffsetWithTermVector = b;
}

- (BOOL) omitNorms
{
	return omitNorms;
}

- (void) setOmitNorms: (BOOL) b
{
	omitNorms = b;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"LCFieldInfo: <%@> %d %d %d %d", name, number, storeTermVector, storePositionWithTermVector, storeOffsetWithTermVector];
}

@end
