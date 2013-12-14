/*
	Copyright (C) 2012 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  March 2012
	License:  MIT  (see COPYING)
 */

#import "COSequenceEdit.h"

static BOOL COOverlappingRanges(NSRange r1, NSRange r2)
{
	return (r1.location >= r2.location && r1.location < (r2.location + r2.length) && r1.length > 0)
	|| (r2.location >= r1.location && r2.location < (r1.location + r1.length) && r2.length > 0);
}

@implementation COSequenceEdit

@synthesize range;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			  range: (NSRange)aRange
{
	self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier];
	range = aRange;
	return self;
}

- (NSComparisonResult) compare: (COSequenceEdit*)other
{
	if ([other range].location > [self range].location)
	{
		return NSOrderedAscending;
	}
	if ([other range].location == [self range].location)
	{
		return NSOrderedSame;
	}
	else
	{
		return NSOrderedDescending;
	}
}

- (BOOL) overlaps: (COSequenceEdit *)other
{
	return COOverlappingRanges(range, other.range);
}

- (BOOL) touches: (COSequenceEdit *)other
{
    if (COOverlappingRanges(range, other.range))
    {
        return YES;
    }
    
    if (range.location == NSMaxRange(other.range))
        return YES;
    
    if (range.location == other.range.location)
        return YES;
    
    if (NSMaxRange(range) == NSMaxRange(other.range))
        return YES;
    
    if (NSMaxRange(range) == other.range.location)
        return YES;

    return NO;
}

- (BOOL) isEqualIgnoringSourceIdentifier:(id)other
{
	return [super isEqualIgnoringSourceIdentifier: other]
    && NSEqualRanges(range, ((COSequenceEdit*)other).range);
}

- (NSUInteger) hash
{
	return 9723954873297612448ULL ^ [super hash] ^ range.location ^ range.length;
}

- (BOOL) isSameKindOfEdit: (COItemGraphEdit*)anEdit
{
	return [anEdit isKindOfClass: [COSequenceEdit class]];
}

@end