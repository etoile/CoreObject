/**
	Copyright (C) 2012 Eric Wasylishen

	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import "COItemGraphEdit.h"

@interface COSetInsertion : COItemGraphEdit
{
	COType type;
	id object;
}
@property (readonly, nonatomic) COType type;
@property (readonly, nonatomic) id object;

- (instancetype) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			   type: (COType)aType
			 object: (id)anObject NS_DESIGNATED_INITIALIZER;

@end
