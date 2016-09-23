/**
	Copyright (C) 2012 Eric Wasylishen

	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import "COSequenceModification.h"

@interface COSequenceInsertion : COSequenceModification

- (instancetype) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
		   location: (NSUInteger)aLocation
			   type: (COType)aType
			objects: (NSArray *)anArray NS_DESIGNATED_INITIALIZER;

@end
