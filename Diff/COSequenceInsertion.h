/*
	Copyright (C) 2012 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import "COSequenceModification.h"

@interface COSequenceInsertion : COSequenceModification

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
		   location: (NSUInteger)aLocation
			   type: (COType)aType
			objects: (NSArray *)anArray;

@end
