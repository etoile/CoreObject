#include "LCField.h"
#include "GNUstep.h"

/**
A field is a section of a Document.  Each field has two parts, a name and a
 value.  Values may be free text, provided as a String or as a Reader, or they
 may be atomic keywords, which are not further processed.  Such keywords may
 be used to represent dates, urls, etc.  Fields are optionally stored in the
 index, so that they may be returned with hits on the document.
 */

@implementation LCField
- (id) init
{
	self = [super init];
	ASSIGN(name, [NSString stringWithCString: "body"]);
	fieldsData = nil;
	storeTermVector = NO;
	storeOffsetWithTermVector = NO;
	storePositionWithTermVector = NO;
	isStored = NO;
	isIndexed = YES;
	isTokenized = YES;
	isBinary = NO;
	isCompressed = NO;
	omitNorms = NO;
	boost = 1.0f;
	return self;
}

- (void) dealloc
{
	DESTROY(name);
	DESTROY(fieldsData);
	[super dealloc];
}

/** Sets the boost factor hits on this field.  This value will be
* multiplied into the score of all hits on this this field of this
* document.
*
* <p>The boost is multiplied by {@link Document#getBoost()} of the document
* containing this field.  If a document has multiple fields with the same
* name, all such values are multiplied together.  This product is then
* multipled by the value {@link Similarity#lengthNorm(String,int)}, and
* rounded by {@link Similarity#encodeNorm(float)} before it is stored in the
* index.  One should attempt to ensure that this product does not overflow
* the range of that encoding.
*
* @see Document#setBoost(float)
* @see Similarity#lengthNorm(String, int)
* @see Similarity#encodeNorm(float)
*/
- (void) setBoost: (float) b
{
	boost = b;
}

/** Returns the boost factor for hits on any field of this document.
*
* <p>The default value is 1.0.
*
* <p>Note: this value is not stored directly with the document in the index.
* Documents returned from {@link IndexReader#document(int)} and {@link
	* Hits#doc(int)} may thus not have the same value present as when this field
* was indexed.
*
* @see #setBoost(float)
*/
- (float) boost
{
	return boost;
}

/** Returns the name of the field as an interned string.
* For example "date", "title", "body", ...
*/
- (NSString *) name
{
	return name;
}

/** The value of the field as a String, or null.  If null, the Reader value
* or binary value is used.  Exactly one of string(), reader(), and
* data() must be set. */
- (NSString *) string
{
	if ([fieldsData isKindOfClass: [NSString class]])
		return (NSString *) fieldsData;
	else
		return nil; 
}

/** The value of the field as a Reader, or null.  If null, the String value
* or binary value is  used.  Exactly one of string(), reader(),
* and data() must be set. */
- (id <LCReader>) reader
{ 
	if ([fieldsData conformsToProtocol: @protocol(LCReader)])
		return (id <LCReader>)fieldsData; 
	else
		return nil;
}

/** The value of the field in Binary, or null.  If null, the Reader or
* String value is used.  Exactly one of string(), reader() and
* data() must be set. */
- (NSData *) data
{
	if ([fieldsData isKindOfClass: [NSData class]])
		return (NSData *)fieldsData;
	else
		return nil;
}

/**
* Create a field by specifying its name, value and how it will
 * be saved in the index. Term vectors will not be stored in the index.
 * 
 * @param name The name of the field
 * @param value The string to process
 * @param store Whether <code>value</code> should be stored in the index
 * @param index Whether the field should be indexed, and if so, if it should
 *  be tokenized before indexing 
 * @throws NullPointerException if name or value is <code>null</code>
 * @throws IllegalArgumentException if the field is neither stored nor indexed
 */
- (LCField *) initWithName: (NSString *) n
                    string: (NSString *) string
					 store: (LCStore_Type) store
					 index: (LCIndex_Type) index
{
	return [self initWithName: n
					   string: string
						store: store
						index: index
				   termVector: LCTermVector_NO];
}

/**
* Create a field by specifying its name, value and how it will
 * be saved in the index.
 * 
 * @param name The name of the field
 * @param value The string to process
 * @param store Whether <code>value</code> should be stored in the index
 * @param index Whether the field should be indexed, and if so, if it should
 *  be tokenized before indexing 
 * @param termVector Whether term vector should be stored
 * @throws NullPointerException if name or value is <code>null</code>
 * @throws IllegalArgumentException in any of the following situations:
 * <ul> 
 *  <li>the field is neither stored nor indexed</li> 
 *  <li>the field is not indexed but termVector is <code>TermVector.YES</code></li>
 * </ul>    */
- (LCField *) initWithName: (NSString *) n
					string: (NSString *) value 
					 store: (LCStore_Type) store
					 index: (LCIndex_Type) index
				termVector: (LCTermVector_Type) termVector
{
	self = [self init];
	if (n == nil) {
		NSLog(@"name cannot be null");
		return nil;
	}
	
	if (value == nil) {
		NSLog(@"value cannot be null");
		return nil;
	}
	
	if ((index == LCIndex_NO) && (store == LCStore_NO))
    {
		NSLog(@"it dones't make sense to have a field that is neither indexed nor stored");
		return nil;
    }
	
	if ((index == LCIndex_NO) && (termVector != LCTermVector_NO))
    {
		NSLog(@"cannot store term vector information for a field that is not indexed");
		return nil;
    }
	ASSIGN(name, n); // this.name = name.intern(); // field names are interned
	ASSIGN(fieldsData, value);
	
	if (store == LCStore_YES) {
		isStored = YES;
		isCompressed = NO;
	}
	else if (store == LCStore_Compress) {
		isStored = YES;
		isCompressed = YES;
	}
	else if (store == LCStore_NO) {
		isStored = NO;
		isCompressed = NO;
	}
	else
	{
		NSLog(@"Unknown store parameter %d", store);
	}
	
	if (index == LCIndex_NO) {
		isIndexed = NO;
		isTokenized = NO;
	} else if (index == LCIndex_Tokenized) {
		isIndexed = YES;
		isTokenized = YES;
	} else if (index == LCIndex_Untokenized) {
		isIndexed = YES;
		isTokenized = NO;
	} else if (index == LCIndex_NoNorms) {
		isIndexed = YES;
		isTokenized = NO;
		omitNorms = YES;
	} else {
		NSLog(@"Unknown index parameter %d", index);
	}
	
	isBinary = NO;
	[self setStoreTermVector: termVector];
	
	return self;
}

/**
* Create a tokenized and indexed field that is not stored. Term vectors will
 * not be stored.
 * 
 * @param name The name of the field
 * @param reader The reader with the content
 * @throws NullPointerException if name or reader is <code>null</code>
 */
- (LCField *) initWithName: (NSString *) n
					reader: (id <LCReader>) reader
{
	return [self initWithName: n reader: reader termVector: LCTermVector_NO];
}

/**
* Create a tokenized and indexed field that is not stored, optionally with 
 * storing term vectors.
 * 
 * @param name The name of the field
 * @param reader The reader with the content
 * @param termVector Whether term vector should be stored
 * @throws NullPointerException if name or reader is <code>null</code>
 */
- (LCField *) initWithName: (NSString *) n
					reader: (id <LCReader>) reader
				termVector: (LCTermVector_Type) termVector
{
	self = [self init];
	if (n == nil) {
		NSLog(@"name cannot be null");
		return nil;
	}
	if (reader == nil) {
		NSLog(@"reader cannot be nil");
		return nil;
	}
	
	ASSIGN(name, n);
	ASSIGN(fieldsData, reader);
	isStored = NO;
	isCompressed = NO;
	isIndexed = YES;
	isTokenized = YES;
	isBinary = NO;
	
	[self setStoreTermVector: termVector];
	return self;
}

/**
* Create a stored field with binary value. Optionally the value may be compressed.
 * 
 * @param name The name of the field
 * @param value The binary value
 * @param store How <code>value</code> should be stored (compressed or not.)
 */
- (id) initWithName: (NSString *) n
			  data: (NSData *) value
			  store: (LCStore_Type) store
{ 
	self = [self init];
	if (n == nil) {
		NSLog(@"name cannot be null");
		return nil;
	}
	if (value == nil) {
		NSLog(@"value cannot be nil");
		return nil;
	}
	
	ASSIGN(name, n);
	ASSIGN(fieldsData, value);
	
	if (store == LCStore_YES) {
		isStored = YES;
		isCompressed = NO;
	} else if (store == LCStore_Compress) {
		isStored = YES;
		isCompressed = YES;
	} else if (store == LCStore_NO) {
		NSLog(@"binary values can't be unstored");
	} else {
		NSLog(@"unknown store parameter %d", store);
	}
	
	isIndexed = NO;
	isTokenized = NO;
	isBinary = YES;
	
	[self setStoreTermVector: LCTermVector_NO];
	return self;
}

- (void) setStoreTermVector: (LCTermVector_Type) termVector
{
	if (termVector == LCTermVector_NO) {
		storeTermVector = NO;
		storePositionWithTermVector = NO;
		storeOffsetWithTermVector = NO;
	} else if (termVector == LCTermVector_YES) {
		storeTermVector = YES;
		storePositionWithTermVector = NO;
		storeOffsetWithTermVector = NO;
	} else if (termVector == LCTermVector_WithPositions) {
		storeTermVector = YES;
		storePositionWithTermVector = YES;
		storeOffsetWithTermVector = NO;
	} else if (termVector == LCTermVector_WithOffsets) {
		storeTermVector = YES;
		storePositionWithTermVector = NO;
		storeOffsetWithTermVector = YES;
	} else if (termVector == LCTermVector_WithPositionsAndOffsets) {
		storeTermVector = YES;
		storePositionWithTermVector = YES;
		storeOffsetWithTermVector = YES;
	} else {
		NSLog(@"unknown termVector parameter %d", termVector);
	}
}

/** True iff the value of the field is to be stored in the index for return
with search hits.  It is an error for this to be true if a field is
Reader-valued. */
- (BOOL) isStored
{
	return isStored; 
}

/** True iff the value of the field is to be indexed, so that it may be
searched on. */
- (BOOL) isIndexed
{ 
	return isIndexed; 
}

/** True iff the value of the field should be tokenized as text prior to
indexing.  Un-tokenized fields are indexed as a single word and may not be
Reader-valued. */
- (BOOL) isTokenized
{ 
	return isTokenized; 
}

/** True if the value of the field is stored and compressed within the index */
- (BOOL) isCompressed
{
	return isCompressed;
}

/** True iff the term or terms used to index this field are stored as a term
*  vector, available from {@link IndexReader#getTermFreqVector(int,String)}.
*  These methods do not provide access to the original content of the field,
*  only to terms used to index it. If the original content must be
*  preserved, use the <code>stored</code> attribute instead.
*
* @see IndexReader#getTermFreqVector(int, String)
*/
- (BOOL) isTermVectorStored
{ 
	return storeTermVector; 
}

/**
* True iff terms are stored as term vector together with their offsets 
 * (start and end positon in source text).
 */
- (BOOL) isOffsetWithTermVectorStored
{
	return storeOffsetWithTermVector;
}

/**
* True iff terms are stored as term vector together with their token positions.
 */
- (BOOL) isPositionWithTermVectorStored
{
	return storePositionWithTermVector;
}

/** True iff the value of the filed is stored as binary */
- (BOOL) isData
{
	return isBinary;
}

- (BOOL) omitNorms
{
	return omitNorms;
}

- (void) setOmitNorms: (BOOL) b
{
	omitNorms = b;
}


/** Prints a Field for human consumption. */
- (NSString *) description 
{
	NSMutableString *result = [NSMutableString string];
	if (isStored) {
		[result appendString: @"stored"];
		if (isCompressed)
			[result appendString: @"/compressed"];
		else
			[result appendString: @"/uncompressed"];
	}
	if (isIndexed) {
		if ([result length] > 0)
			[result appendString: @","];
		[result appendString: @"indexed"];
	}
	if (isTokenized) {
		if ([result length] > 0)
			[result appendString: @","];
		[result appendString: @"tokenized"];
	}
	if (storeTermVector) {
		if ([result length] > 0)
			[result appendString: @","];
		[result appendString: @"termVector"];
	}
	if (storeOffsetWithTermVector) {
		if ([result length] > 0)
			[result appendString: @","];
		[result appendString: @"termVectorOffsets"];
	}
	if (storePositionWithTermVector) {
		if ([result length] > 0)
			[result appendString: @","];
		[result appendString: @"termVectorPosition"];
	}
	if (isBinary) {
		if ([result length] > 0)
			[result appendString: @","];
		[result appendString: @"binary"];
	}
	if (omitNorms) {
		[result appendString: @",omitNorms"];
	}
	
	[result appendFormat: @"<%@:", name];
	
	if (fieldsData != nil)
	{
		[result appendFormat: @"%@>", fieldsData];
	}
	
	return result;
}

@end
