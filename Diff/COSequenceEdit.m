#import "COSequenceEdit.h"
#import "COSequenceMerge.h"

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