/*
	Copyright (C) 2012 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import "COItemGraphEdit.h"

@interface COSequenceEdit : COItemGraphEdit
{
	NSRange range;
}
@property (readonly, nonatomic) NSRange range;

- (NSComparisonResult) compare: (id)otherObject;
- (BOOL) overlaps: (COSequenceEdit *)other;
- (BOOL) touches: (COSequenceEdit *)other;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			  range: (NSRange)aRange;

@end
