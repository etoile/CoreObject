#include "LCScoreDocComparator.h"
#include "LCScoreDoc.h"
#include "LCSortField.h"

/** Special comparator for sorting hits according to computed relevance (document score). */
@implementation LCRelevanceScoreDocComparator

- (NSComparisonResult) compare: (LCScoreDoc *) i to: (LCScoreDoc *) j
{
	if ([i score] > [j score]) return NSOrderedAscending;
	else if ([i score] < [j score]) return NSOrderedDescending;
	else return NSOrderedSame;
}

- (id) sortValue: (LCScoreDoc *) doc
{
	return [NSNumber numberWithFloat: (float)[doc score]];
}

- (int) sortType
{
	return LCSortField_SCORE;
}

@end

/** Special comparator for sorting hits according to index order (document number). */
@implementation LCIndexOrderScoreDocComparator
- (NSComparisonResult) compare: (LCScoreDoc *) i to: (LCScoreDoc *) j
{
	if ([i document] < [j document]) return NSOrderedAscending;
	else if ([i document] > [j document]) return NSOrderedDescending;
	else return NSOrderedSame;
}

- (id) sortValue: (LCScoreDoc *) doc
{
	return [NSNumber numberWithInt: (int)[doc document]];
}

- (int) sortType
{
	return LCSortField_DOC;
}

@end
