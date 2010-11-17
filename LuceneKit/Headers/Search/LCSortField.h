#ifndef __LUCENE_SEARCH_SORT_FIELD__
#define __LUCENE_SEARCH_SORT_FIELD__

#include <Foundation/Foundation.h>
#include "LCSortComparatorSource.h"

typedef enum _LCSortFieldType {
	/** Sort by document score (relevancy).  Sort values are Float and higher
	* values are at the front. */
	LCSortField_SCORE = 0,
	/** Sort by document number (index order).  Sort values are Integer and lower
	* values are at the front. */
	LCSortField_DOC = 1,
	/** Guess type of sort based on field contents.  A regular expression is used
	* to look at the first term indexed for the field and determine if it
	* represents an integer number, a floating point number, or just arbitrary
	* string characters. */
	LCSortField_AUTO = 2,
	/** Sort using term values as Strings.  Sort values are String and lower
	* values are at the front. */
	LCSortField_STRING = 3,
	/** Sort using term values as encoded Integers.  Sort values are Integer and
	* lower values are at the front. */
	LCSortField_INT = 4,
	/** Sort using term values as encoded Floats.  Sort values are Float and
	* lower values are at the front. */
	LCSortField_FLOAT = 5,
	/** Sort using a custom Comparator.  Sort values are any Comparable and
	* sorting is done according to natural order. */
	LCSortField_CUSTOM = 9
} LCSortFieldType;

@interface LCSortField: NSObject
{
	NSString *field;
	LCSortFieldType type;  // defaults to determining type dynamically
        id locale;    // defaults to "natural order" (no Locale)
	BOOL reverse;  // defaults to natural order
	id factory;
}
/** Represents sorting by document score (relevancy). */
+ (LCSortField *) sortField_SCORE;
	/** Represents sorting by document number (index order). */
+ (LCSortField *) sortField_DOC;

- (id) initWithField: (NSString *) field;
- (id) initWithField: (NSString *) field reverse: (BOOL) reverse;
- (id) initWithField: (NSString *) field type: (LCSortFieldType) type;
- (id) initWithField: (NSString *) field type: (LCSortFieldType) type
			 reverse: (BOOL) reverse;
- (id) initWithField: (NSString *) field locale: (id) locale;
- (id) initWithField: (NSString *) field locale: (id) locale 
             reverse: (BOOL) reverse;

- (id) initWithField: (NSString *) field
		  comparator: (id) comparator;
- (id) initWithField: (NSString *) field
		  comparator: (id) comparator
			 reverse: (BOOL) reverse;
- (NSString *) field;
- (LCSortFieldType) type;
- (id) locale;
- (BOOL) reverse;
- (id) factory;
@end

#endif /* __LUCENE_SEARCH_SORT_FIELD__ */
