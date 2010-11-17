#ifndef __LUCENE_DOCUMENT_FIELD__
#define __LUCENE_DOCUMENT_FIELD__

#include <Foundation/Foundation.h>
#include "LCReader.h"

/** Specify whether to store a value in field.
 * LCStore_Compress: store a value in compressed form.
 * LCStore_YES: store a value as it is.
 * LCStore_NO: do not store a value.
 * LCStore does not conflict with LCIndex.
 */
typedef enum _LCStore_Type {
	LCStore_Compress,
	LCStore_YES,
	LCStore_NO
} LCStore_Type;

/** Specify whether to index a value in fiend.
 * LCIndex_NO: Do not index the value.
 * LCIndex_Tokenized: Index the tokenized value.
 * LCIndex_Untokenized: Index the value as it is.
 */
typedef enum _LCIndex_Type {
	LCIndex_NO,
	LCIndex_Tokenized,
	LCIndex_Untokenized,
	LCIndex_NoNorms
} LCIndex_Type;

/** Specify whether to vectorize a term
 * LCTermVector_NO: do not vectorize the term.
 * LCTermVector_YES: vectorize the term (frequency).
 * LCTermVector_WithPositions: vectorize the term (frequency and position).
 * LCTermVector_WithOffsets: vectorize the term (frequency and offset).
 * LCTermVector_WithPositionsAndOffsets: vectorize the term (frequency, position and offset).
 */
typedef enum _LCTermVector_Type {
	LCTermVector_NO,
	LCTermVector_YES,
	LCTermVector_WithPositions,
	LCTermVector_WithOffsets,
	LCTermVector_WithPositionsAndOffsets
} LCTermVector_Type;

/** Each field is a record to be stored, indexed and searched.
 * Each field is associated with a name and a value.
 * The value can be a string (NSString), a reader (LCReader), or a data (NSData) exclusively.
 * Reader should not be indexed.
 * Data should not be indexed and vectorized.
 */
@interface LCField: NSObject
{
	NSString *name;
	id fieldsData;
	BOOL storeTermVector;
	BOOL storeOffsetWithTermVector;
	BOOL storePositionWithTermVector;
	BOOL isStored, isIndexed, isTokenized;
	BOOL isBinary, isCompressed;
	BOOL omitNorms;
	float boost;
}

/** Set boost for this field */
- (void) setBoost: (float) boost;
/** Boost of this field */
- (float) boost;
/** Name of this field */
- (NSString *) name;
/** The value of this field (NSString) */
- (NSString *) string;
/** The value of this field (LCReader) */
- (id <LCReader>) reader;
/** The value of this field (NSData */
- (NSData *) data;
/** Initiate with string */
- (LCField *) initWithName: (NSString *) name
					string: (NSString *) string
					 store: (LCStore_Type) store
					 index: (LCIndex_Type) index;
/** Initiate with string and vectorized */
- (LCField *) initWithName: (NSString *) name
					string: (NSString *) string
					 store: (LCStore_Type) store
					 index: (LCIndex_Type) index
				termVector: (LCTermVector_Type) tv;
/** Initiate with reader */
- (LCField *) initWithName: (NSString *) name
					reader: (id <LCReader>) reader;
/** Initiate with reader and vectorized */
- (LCField *) initWithName: (NSString *) name
					reader: (id <LCReader>) reader
				termVector: (LCTermVector_Type) termVector;
/** Initiate with data */
- (id) initWithName: (NSString *) name
			  data: (NSData *) value
			  store: (LCStore_Type) store;
/** Set type of vectorization */
- (void) setStoreTermVector: (LCTermVector_Type) termVector;
/** Is value stored */
- (BOOL) isStored;
/** Is value indexed */
- (BOOL) isIndexed;
/** Is value tokenized */
- (BOOL) isTokenized;
/** Is value compressed */
- (BOOL) isCompressed;
/** Is value vectorized (frequency) */
- (BOOL) isTermVectorStored;
/** Is value vectorized (frequency, offset) */
- (BOOL) isOffsetWithTermVectorStored;
/** Is value vectorized (frequency, position) */
- (BOOL) isPositionWithTermVectorStored;
/** Is value a data (NSData) */
- (BOOL) isData;

- (BOOL) omitNorms;
- (void) setOmitNorms: (BOOL) b;

@end

#endif /* __LUCENE_DOCUMENT_FIELD__ */
