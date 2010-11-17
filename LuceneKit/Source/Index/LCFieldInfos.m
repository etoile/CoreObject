#include "LCFieldInfos.h"
#include "GNUstep.h"

/** Access to the Field Info file that describes document fields and whether or
*  not they are indexed. Each segment has a separate Field Info file. Objects
*  of this class are thread-safe for multiple readers, but only one thread can
*  be adding documents at a time, with no other reader or writer threads
*  accessing this object.
*/

@interface LCFieldInfos (LCPrivate)
- (void) addInternal: (NSString *) name
		   isIndexed: (BOOL) isIndexed
  isTermVectorStored: (BOOL)isTermVectorStored
         isStorePositionWithTermVector: (BOOL) isStorePositionWithTermVector
         isStoreOffsetWithTermVector: (BOOL) isStoreOffsetWithTermVector
	omitNorms: (BOOL) ons;
- (void) read: (LCIndexInput *) input;
@end

#define IS_INDEXED 0x1
#define STORE_TERMVECTOR 0x2
#define STORE_POSITIONS_WITH_TERMVECTOR 0x4
#define STORE_OFFSET_WITH_TERMVECTOR 0x8
#define OMIT_NORMS 0x10

@implementation LCFieldInfos

- (id) init
{
	self = [super init];
	byNumber = [[NSMutableArray alloc] init];
	byName = [[NSMutableDictionary alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(byNumber);
	DESTROY(byName);
	[super dealloc];
}

/**
* Construct a FieldInfos object using the directory and the name of the file
 * IndexInput
 * @param d The directory to open the IndexInput from
 * @param name The name of the file to open the IndexInput from in the Directory
 * @throws IOException
 */
- (id) initWithDirectory: (id <LCDirectory>) d name: (NSString *) name
{
	self = [self init];
	LCIndexInput *input = [d openInput: name];
	[self read: input];
	[input close];
	return self;
}

/** Adds field info for a Document. */
- (void) addDocument: (LCDocument *) doc
{
	NSArray *fields = [doc fields];
	NSEnumerator *e = [fields objectEnumerator];
	LCFieldInfo *field;
	while ((field = (LCFieldInfo *)[e nextObject]))
    {
		[self addName: [field name] isIndexed: [field isIndexed]
   isTermVectorStored: [field isTermVectorStored]
   isStorePositionWithTermVector: [field isPositionWithTermVectorStored]
   isStoreOffsetWithTermVector: [field isOffsetWithTermVectorStored]
   omitNorms: [field omitNorms]];
    }
}

/**
* Add fields that are indexed. Whether they have termvectors has to be specified.
 * 
 * @param names The names of the fields
 * @param storeTermVectors Whether the fields store term vectors or not
 * @param storePositionWithTermVector treu if positions should be stored.
 * @param storeOffsetWithTermVector true if offsets should be stored
 */
- (void) addIndexedCollection: (NSArray *) names
			  storeTermVector: (BOOL) storeTermVectors
	 storePositionWithTermVector: (BOOL) storePositionWithTermVector
	storeOffsetWithTermVector: (BOOL) storeOffsetWithTermVector
{
	NSEnumerator *e = [names objectEnumerator];
	id object;
	while ((object = [e nextObject]))
    {
		[self addName: object 
			isIndexed: YES
   isTermVectorStored: storeTermVectors
	    isStorePositionWithTermVector: storePositionWithTermVector
	    isStoreOffsetWithTermVector: storeOffsetWithTermVector];
    }
}

/**
* Assumes the fields are not storing term vectors.
 * 
 * @param names The names of the fields
 * @param isIndexed Whether the fields are indexed or not
 * 
 * @see #add(String, boolean)
 */
- (void) addCollection: (NSArray *) names isIndexed: (BOOL) isIndexed
{
	NSEnumerator *e = [names objectEnumerator];
	id object;
	while ((object = [e nextObject]))
    {
		[self addName: object isIndexed:  isIndexed];
    }
}

/**
* Calls 5 parameter add with false for all TermVector parameters.
 * 
 * @param name The name of the Field
 * @param isIndexed true if the field is indexed
 * @see #add(String, boolean, boolean, boolean, boolean)
 */
- (void) addName: (NSString *) name isIndexed: (BOOL) isIndexed
{
	[self addName: name
        isIndexed: isIndexed
	isTermVectorStored: NO
	isStorePositionWithTermVector: NO
	isStoreOffsetWithTermVector: NO
	omitNorms: NO];
}

/**
* Calls 5 parameter add with false for term vector positions and offsets.
 * 
 * @param name The name of the field
 * @param isIndexed  true if the field is indexed
 * @param storeTermVector true if the term vector should be stored
 */
- (void) addName: (NSString *) name        
	   isIndexed: (BOOL) isIndexed                   
	 isTermVectorStored: (BOOL)isTermVectorStored
{
	[self addName: name
        isIndexed: isIndexed
	isTermVectorStored: isTermVectorStored
	isStorePositionWithTermVector: NO
	isStoreOffsetWithTermVector: NO
	omitNorms: NO];
}

/** If the field is not yet known, adds it. If it is known, checks to make
*  sure that the isIndexed flag is the same as was given previously for this
*  field. If not - marks it as being indexed.  Same goes for the TermVector
* parameters.
* 
* @param name The name of the field
* @param isIndexed true if the field is indexed
* @param storeTermVector true if the term vector should be stored
* @param storePositionWithTermVector true if the term vector with positions should be stored
* @param storeOffsetWithTermVector true if the term vector with offsets should be stored
*/
- (void) addName: (NSString *) name        
	   isIndexed: (BOOL) isIndexed                   
	 isTermVectorStored: (BOOL) storeTermVector
	 isStorePositionWithTermVector: (BOOL) storePositionWithTermVector
  	 isStoreOffsetWithTermVector: (BOOL) storeOffsetWithTermVector
{
	[self addName: name
		isIndexed: isIndexed
		isTermVectorStored: storeTermVector
		isStorePositionWithTermVector: storePositionWithTermVector
		isStoreOffsetWithTermVector: storeOffsetWithTermVector
		omitNorms: NO];
}

- (void) addName: (NSString *) name        
	   isIndexed: (BOOL) isIndexed                   
	 isTermVectorStored: (BOOL) storeTermVector
	 isStorePositionWithTermVector: (BOOL) storePositionWithTermVector
  	 isStoreOffsetWithTermVector: (BOOL) storeOffsetWithTermVector
	omitNorms: (BOOL) ons
{
	LCFieldInfo *fi = [self fieldInfo: name];
	if (fi == nil) {
		[self addInternal: name 
				isIndexed: isIndexed 
	   isTermVectorStored: storeTermVector
	    isStorePositionWithTermVector: storePositionWithTermVector
	    isStoreOffsetWithTermVector: storeOffsetWithTermVector
		omitNorms: ons];
    } else {
		if ([fi isIndexed] != isIndexed) {
			[fi setIndexed: YES];              // once indexed, always index
		}
		if ([fi isTermVectorStored] != storeTermVector) {
			[fi setTermVectorStored: YES];    // once vector, always vector
		}
		if ([fi isPositionWithTermVectorStored] != storePositionWithTermVector) {
			[fi setPositionWithTermVectorStored: YES]; // once vector, always vector
		}
		if ([fi isOffsetWithTermVectorStored] != storeOffsetWithTermVector) {
			[fi setOffsetWithTermVectorStored: YES]; // once vector, always vector
		}
		if ([fi omitNorms] != ons) {
			[fi setOmitNorms: NO]; // once norms are stored, always store 
		}
    }
}

- (void) addInternal: (NSString *) name
		   isIndexed: (BOOL) isIndexed
  isTermVectorStored: (BOOL)isTermVectorStored
         isStorePositionWithTermVector: (BOOL) isStorePositionWithTermVector
         isStoreOffsetWithTermVector: (BOOL) isStoreOffsetWithTermVector
	omitNorms: (BOOL) ons;
{
	LCFieldInfo *fi = [[LCFieldInfo alloc] initWithName: AUTORELEASE([name copy])
											  isIndexed: isIndexed
												 number: [byNumber count]
										storeTermVector: isTermVectorStored
							storePositionWithTermVector: isStorePositionWithTermVector
							  storeOffsetWithTermVector: isStoreOffsetWithTermVector
	omitNorms: ons];
	[byNumber addObject: fi];
	[byName setObject: fi forKey: name];
	DESTROY(fi);
}

- (int) fieldNumber: (NSString *) fieldName
{
	LCFieldInfo *fi = [self fieldInfo: fieldName];
	if (fi)
		return [fi number];
	else
		return -1;
}

- (LCFieldInfo *) fieldInfo: (NSString *) fieldName
{
	return [byName objectForKey: fieldName];
}

/**
* Return the fieldName identified by its number.
 * 
 * @param fieldNumber
 * @return the fieldName or an empty string when the field
 * with the given number doesn't exist.
 */  
- (NSString *) fieldName: (int) fieldNumber
{
	LCFieldInfo *info = [self fieldInfoWithNumber: fieldNumber];
	if (info)
		return [info name];
	else
		return @"";
}

/**
* Return the fieldinfo object referenced by the fieldNumber.
 * @param fieldNumber
 * @return the FieldInfo object or null when the given fieldNumber
 * doesn't exist.
 */   
- (LCFieldInfo *) fieldInfoWithNumber: (int) number
{
	if (number < [byNumber count])
    {
		LCFieldInfo *info = [byNumber objectAtIndex: number];
		return info;
    }
	else
		return nil;
}

- (int) size
{
	return [byNumber count];
}

- (BOOL) hasVectors
{
	BOOL hasVectors = NO;
	int i, count = [self size];
	for (i = 0; i < count; i++) 
    {
		if ([[self fieldInfoWithNumber: i] isTermVectorStored]) 
        {
			hasVectors = YES;
			break;
		}
    }
	return hasVectors;
}

- (void) write: (id <LCDirectory>) d name: (NSString *) name
{
	LCIndexOutput *output = [d createOutput: name];
	[self write: output];
	[output close];
}

- (void) write: (LCIndexOutput *) output
{
	[output writeVInt: (long)[self size]];
	int i, count = [self size];
	for (i = 0; i < count; i++) {
		LCFieldInfo *fi = [self fieldInfoWithNumber: i];
		char bits = 0x0;
		if ([fi isIndexed]) bits |= IS_INDEXED;
		if ([fi isTermVectorStored]) bits |= STORE_TERMVECTOR;
		if ([fi isPositionWithTermVectorStored]) bits |= STORE_POSITIONS_WITH_TERMVECTOR;
		if ([fi isOffsetWithTermVectorStored]) bits |= STORE_OFFSET_WITH_TERMVECTOR;
		if ([fi omitNorms]) bits |= OMIT_NORMS;
		[output writeString: [fi name]];
		[output writeByte: bits];
    }
}

- (void) read: (LCIndexInput *) input
{
	long size = [input readVInt]; // read in the size
	int i;
	NSString *name;
	for (i = 0; i < size; i++) {
		name = [input readString];//.intern();
		char bits = [input readByte];
		BOOL isIndexed = ((bits & IS_INDEXED) != 0);
		BOOL storeTermVector = ((bits & STORE_TERMVECTOR) != 0);
		BOOL storePositionsWithTermVector = ((bits & STORE_POSITIONS_WITH_TERMVECTOR) != 0);
		BOOL storeOffsetWithTermVector = ((bits & STORE_OFFSET_WITH_TERMVECTOR) != 0);
		BOOL ons = ((bits & OMIT_NORMS) != 0);
		[self addInternal: name
				isIndexed: isIndexed
	   isTermVectorStored: storeTermVector
            isStorePositionWithTermVector: storePositionsWithTermVector
            isStoreOffsetWithTermVector: storeOffsetWithTermVector
		omitNorms: ons];
    }    
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"LCFieldInfos: %@", byNumber];
}

@end

