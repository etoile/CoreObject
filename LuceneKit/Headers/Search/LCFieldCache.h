#ifndef __LUCENE_SEARCH_FIELD_CACHE__
#define __LUCENE_SEARCH_FIELD_CACHE__

#include <Foundation/Foundation.h>
#include "LCSortComparator.h"
#include "LCIndexReader.h"

@interface LCIntParser: NSObject
- (int) parseInt: (NSString *) value;
@end

@interface LCFloatParser: NSObject
- (float) parseFloat: (NSString *) value;
@end

/** Indicator for StringIndex values in the cache. */
// NOTE: the value assigned to this constant must not be
// the same as any of those in SortField!!
//
//static int LCFieldCache_STRING_INDEX = -1;
/** Expert: Stores term text values and document ordering data. */
@interface LCStringIndex: NSObject
{
	/** All the term values, in natural order. */
	NSArray *lookup;
	/** For each document, an index into the lookup array. */
	/* LuceneKit: key is document number, value is the index in lookup above */
	NSDictionary *order;
}

/** Creates one of these objects */
- (id) initWithOrder: (NSDictionary *) values lookup: (NSArray *) lookup;
- (NSDictionary *) order;
- (NSArray *) lookup;
@end

@interface LCFieldCache: NSObject
{
}

/** Checks the internal cache for an appropriate entry, and if none is
* found, reads the terms in <code>field</code> as integers and returns an array
* of size <code>reader.maxDoc()</code> of the value each document
* has in the given field.
*/
+ (LCFieldCache *) defaultCache;
	/* LuceneKit: 
	* original lucene return array, in which document number is the index.
	* Because there may be gap in array and NSArray cannot have nil,
	* use NSDictionary, in which document number is key (NSNumber)
	*/
- (NSDictionary *) ints: (LCIndexReader *) reader field: (NSString *) field;
- (NSDictionary *) ints: (LCIndexReader *) reader field: (NSString *) field
                   parser: (LCIntParser *) parser;
- (NSDictionary *) floats: (LCIndexReader *) reader field: (NSString *) field;
- (NSDictionary *) floats: (LCIndexReader *) reader field: (NSString *) field
                   parser: (LCFloatParser *) parser;
- (NSDictionary *) strings: (LCIndexReader *) reader field: (NSString *) field;
- (LCStringIndex *) stringIndex: (LCIndexReader *) reader 
						  field: (NSString *) field;
- (id) objects: (LCIndexReader *) reader field: (NSString *) field;
- (NSDictionary *) custom: (LCIndexReader *) reader field: (NSString *) field 
		   sortComparator: (LCSortComparator *) comparator;

@end

#endif /* __LUCENE_SEARCH_FIELD_CACHE__ */
