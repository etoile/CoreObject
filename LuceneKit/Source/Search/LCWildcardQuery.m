#include "LCWildcardQuery.h"
#include "LCWildcardTermEnum.h"
#include "GNUstep.h"

/* Use OgreKit for wildcard, which is caseless by default */
/** Implements the wildcard search query. Supported wildcards are <code>*</code>, which
 * matches any character sequence (including the empty one), and <code>?</code>,
 * which matches any single character. Note this query can be slow, as it
 * needs to iterate over many terms. In order to prevent extremely slow WildcardQueries,
 * a Wildcard term should not start with one of the wildcards <code>*</code> or
 * <code>?</code>.
 * 
 * @see WildcardTermEnum
 */
@implementation LCWildcardQuery

- (LCFilteredTermEnumerator *) enumerator: (LCIndexReader *) reader
{
	return AUTORELEASE([[LCWildcardTermEnumerator alloc] initWithReader: reader term: [self term]]);
}

- (BOOL) isEqual: (id) o
{
	if ([o isKindOfClass: [LCWildcardQuery class]])
	{
		return [super isEqual: o];
	}
	return NO;
}

@end
