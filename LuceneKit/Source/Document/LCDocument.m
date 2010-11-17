#include "LCDocument.h"
#include "GNUstep.h"

/** Documents are the unit of indexing and search.
*
* A Document is a set of fields.  Each field has a name and a textual value.
* A field may be {@link Field#isStored() stored} with the document, in which
* case it is returned with search hits on the document.  Thus each document
* should typically contain one or more stored fields which uniquely identify
* it.
*
* <p>Note that fields which are <i>not</i> {@link Field#isStored() stored} are
* <i>not</i> available in documents retrieved from the index, e.g. with {@link
	* Hits#doc(int)}, {@link Searcher#doc(int)} or {@link
		* IndexReader#document(int)}.
*/

@implementation LCDocument

- (id) init
{
	self = [super init];
	fields = [[NSMutableArray alloc] init];
	boost = 1.0f;
	return self;
}

- (void) dealloc
{
	DESTROY(fields);
	[super dealloc];
}

/** Sets a boost factor for hits on any field of this document.  This value
* will be multiplied into the score of all hits on this document.
*
* <p>Values are multiplied into the value of {@link Field#getBoost()} of
* each field in this document.  Thus, this method in effect sets a default
* boost for the fields of this document.
*
* @see Field#setBoost(float)
*/
- (void) setBoost: (float) b
{
	boost = b;
}

/** Returns the boost factor for hits on any field of this document.
*
* <p>The default value is 1.0.
*
* <p>Note: This value is not stored directly with the document in the index.
* Documents returned from {@link IndexReader#document(int)} and
* {@link Hits#doc(int)} may thus not have the same value present as when
* this document was indexed.
*
* @see #setBoost(float)
*/
- (float) boost
{
	return boost;
}

/**
* <p>Adds a field to a document.  Several fields may be added with
 * the same name.  In this case, if the fields are indexed, their text is
 * treated as though appended for the purposes of search.</p>
 * <p> Note that add like the removeField(s) methods only makes sense 
 * prior to adding a document to an index. These methods cannot
 * be used to change the content of an existing index! In order to achieve this,
 * a document has to be deleted from an index and a new changed version of that
 * document has to be added.</p>
 */
- (void) addField: (LCField *) f
{
	[fields addObject: f];
}

/**
* <p>Removes field with the specified name from the document.
 * If multiple fields exist with this name, this method removes the first field that has been added.
 * If there is no field with the specified name, the document remains unchanged.</p>
 * <p> Note that the removeField(s) methods like the add method only make sense 
 * prior to adding a document to an index. These methods cannot
 * be used to change the content of an existing index! In order to achieve this,
 * a document has to be deleted from an index and a new changed version of that
 * document has to be added.</p>
 */
- (void) removeField: (NSString *) n
{
	LCField *field;
	int i, count = [fields count];
	for(i = 0; i < count; i++)
    {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: n])
        {
			[fields removeObjectAtIndex: i];
			return;
		}
    }
}

/**
* <p>Removes all fields with the given name from the document.
 * If there is no field with the specified name, the document remains unchanged.</p>
 * <p> Note that the removeField(s) methods like the add method only make sense 
 * prior to adding a document to an index. These methods cannot
 * be used to change the content of an existing index! In order to achieve this,
 * a document has to be deleted from an index and a new changed version of that
 * document has to be added.</p>
 */

- (void) removeFields: (NSString *) n
{
	LCField *field;
	int i;
	for(i = [fields count]-1; i > -1; i--)
    {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: n])
        {
			[fields removeObjectAtIndex: i];
		}
    }
}

/** Returns a field with the given name if any exist in this document, or
* null.  If multiple fields exists with this name, this method returns the
* first value added.
*/
- (LCField *) field: (NSString *) name
{
	LCField *field;
	int i, count = [fields count];;
	for (i = 0; i < count; i++) 
    {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: name])
			return field;
    }
	return nil;
}

/** Returns the string value of the field with the given name if any exist in
* this document, or null.  If multiple fields exist with this name, this
* method returns the first value added. If only binary fields with this name
* exist, returns null.
*/
- (NSString *) stringForField: (NSString *) name
{
	int i;
	LCField *field;
	for (i = 0; i < [fields count]; i++)
    {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: name] && (![field isData]))
			return [field string];;
    }
	return nil;
}

/** Returns an Enumeration of all the fields in a document. */
- (NSEnumerator *) fieldEnumerator
{
	return [fields objectEnumerator];
}

/**
* Returns an array of {@link Field}s with the given name.
 * This method can return <code>null</code>.
 *
 * @param name the name of the field
 * @return a <code>Field[]</code> array
 */
- (NSArray *) fields: (NSString *) name
{
	LCField *field;
	int i, count = [fields count];;
	NSMutableArray *a = [[NSMutableArray alloc] init];
	for (i = 0; i < count; i++)
    {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: name])
        {
			[a addObject: field];
        }
	}
	if ([a count] > 0)
		return AUTORELEASE(a);
	else
    {
		DESTROY(a);
		return nil;
    }
}

/**
* Returns an array of values of the field specified as the method parameter.
 * This method can return <code>null</code>.
 *
 * @param name the name of the field
 * @return a <code>String[]</code> of field values
 */
- (NSArray *) allStringsForField: (NSString *) name
{
	NSMutableArray *result = [[NSMutableArray alloc] init];
	int i, count = [fields count];
	LCField *field;
	for(i = 0; i < count; i++)
    {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: name] && (![field isData]))
			[result addObject: [field string]];
    }
	if ([result count] > 0)
		return AUTORELEASE(result);
	else
	{
		DESTROY(result);
		return nil;
	}
}

/**
* Returns an array of byte arrays for of the fields that have the name specified
 * as the method parameter. This method will return <code>null</code> if no
 * binary fields with the specified name are available.
 *
 * @param name the name of the field
 * @return a  <code>byte[][]</code> of binary field values.
 */

- (NSArray *) allDataForField: (NSString *) name
{
	NSMutableArray *result = [[NSMutableArray alloc] init];
	int i, count = [fields count];
	LCField *field;
	for (i = 0; i < count; i++) {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: name] && [field isData])
			[result addObject: [field data]];
	}
	if ([result count] > 0)
		return AUTORELEASE(result);
	else
	{
		DESTROY(result);
		return nil;
	}
}

- (NSData *) dataForField: (NSString *) name
{
	int i, count = [fields count];
	LCField *field;
	for (i = 0; i < count; i++) {
		field = [fields objectAtIndex: i];
		if ([[field name] isEqualToString: name] && [field isData])
			return [field data];
	}
	return nil;
}


/** Prints the fields of a document for human consumption. */
- (NSString *) description
{
	NSMutableString *s = [[NSMutableString alloc] init];
	[s appendString: @"Document<"];
	LCField *field;
	int i;
	for (i = 0; i < [fields count]; i++) 
    {
		field = [fields objectAtIndex: i];
		[s appendString: [field description]];
		if (i != [fields count]-1)
			[s appendString: @" "];
    }
    [s appendString: @">"];
    return AUTORELEASE(s);
}

- (NSArray *) fields
{
	return fields;
}

@end

