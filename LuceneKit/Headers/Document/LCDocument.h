#ifndef __LUCENE_DOCUMENT_DOCUMENT__
#define __LUCENE_DOCUMENT_DOCUMENT__

#include <Foundation/Foundation.h>
#include "LCField.h"

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

#ifdef HAVE_UKTEST
#include <UnitKit/UnitKit.h>
@interface LCDocument: NSObject <UKTest>
#else
@interface LCDocument: NSObject
#endif
{
	NSMutableArray *fields;
	float boost;
}

/** Set boost of this document */
- (void) setBoost: (float) boost;
/** Return boost of this document */
- (float) boost;
/** Add field */
- (void) addField: (LCField *) field;
/** Remove the first field with name */
- (void) removeField: (NSString *) name;
/** Remove all fields with name */
- (void) removeFields: (NSString *) name;
/** Remove the first field with name */
- (LCField *) field: (NSString *) name;
/** Remove the string value of the first field with name */
- (NSString *) stringForField: (NSString *) name;
/** Return an enumerator of all fields */
- (NSEnumerator *) fieldEnumerator;
/** Return all fields with name */
- (NSArray *) fields: (NSString *) name;
/** Return all string values of field with name */ 
- (NSArray *) allStringsForField: (NSString *) name;
/** Return all binary values of field with name */
- (NSArray *) allDataForField: (NSString *) name;
/** Return the first binary value of field with name */
- (NSData *) dataForField: (NSString *) name;
/** Return all fields */
- (NSArray *) fields;

@end

#endif
