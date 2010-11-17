#ifndef __LUCENE_DOCUMENT_NUMBER_TOOLS__
#define __LUCENE_DOCUMENT_NUMBER_TOOLS__

#include <Foundation/Foundation.h>

/**
* Provides support for converting longs to Strings, and back again. The strings
 * are structured so that lexicographic sorting order is preserved.
 * 
 * <p>
 * That is, if l1 is less than l2 for any two longs l1 and l2, then
 * NumberTools.longToString(l1) is lexicographically less than
 * NumberTools.longToString(l2). (Similarly for "greater than" and "equals".)
 * 
 * <p>
 * This class handles <b>all</b> long values (unlike
											  * {@link org.apache.lucene.document.DateField}).
 * 
 * @author Matt Quail (spud at madbean dot com)
 */

#define RADIX 36
#define STR_SIZE 13

static NSString *NEGATIVE_PREFIX = @"-";
static NSString *POSITIVE_PREFIX = @"0";

/** Convert between NSString and long long */
@interface NSString (LuceneKit_Document_Number)
/** Convert long long (8 bytes )to NSString */
+ (NSString *) stringWithLongLong: (long long) l;
/** Convert NSString to long long (8 bytes) */
- (long long) longLongValue;
@end

#endif /* __LUCENE_DOCUMENT_NUMBER_TOOLS__ */
