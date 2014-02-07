/**
	Copyright (C) 2012 Eric Wasylishen

	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import "COSequenceEdit.h"

@interface COSequenceModification : COSequenceEdit
{
	COType type;
	NSArray *objects;
}
@property (readonly, nonatomic) COType type;
@property (readonly, nonatomic) NSArray *objects;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			  range: (NSRange)aRange
			   type: (COType)aType
			objects: (NSArray *)anArray;
@end

