#include "LCSortField.h"
#include "GNUstep.h"

/**
* Stores information about how to sort documents by terms in an individual
 * field.  Fields must be indexed in order to sort by them.
 *
 * <p>Created: Feb 11, 2004 1:25:29 PM
 *
 * @author  Tim Jones (Nacimiento Software)
 * @since   lucene 1.4
 * @version $Id$
 * @see Sort
 */

@implementation LCSortField

+ (LCSortField *) sortField_SCORE
{
	return [[LCSortField alloc] initWithField: nil
										 type: LCSortField_SCORE];
}

+ (LCSortField *) sortField_DOC;
{
	return  [[LCSortField alloc] initWithField: nil 
										  type: LCSortField_DOC];
}

- (id) init
{
	self = [super init];
	type = LCSortField_AUTO;
	reverse = NO;
	return self;
}

/** Creates a sort by terms in the given field where the type of term value
* is determined dynamically ({@link #AUTO AUTO}).
* @param field Name of field to sort by, cannot be <code>null</code>.
*/
- (id) initWithField: (NSString *) f
{
	self = [self init];
	ASSIGN(field, f);
	return self;
}

/** Creates a sort, possibly in reverse, by terms in the given field where
* the type of term value is determined dynamically ({@link #AUTO AUTO}).
* @param field Name of field to sort by, cannot be <code>null</code>.
* @param reverse True if natural order should be reversed.
*/
- (id) initWithField: (NSString *) f reverse: (BOOL) r
{
	self = [self initWithField: f];
	reverse = r;
	return self;
}

/** Creates a sort by terms in the given field with the type of term
* values explicitly given.
* @param field  Name of field to sort by.  Can be <code>null</code> if
*               <code>type</code> is SCORE or DOC.
* @param type   Type of values in the terms.
*/
- (id) initWithField: (NSString *) f type: (LCSortFieldType) t
{
	self = [self initWithField: f];
	type = t;
	return self;
}

/** Creates a sort, possibly in reverse, by terms in the given field with the
* type of term values explicitly given.
* @param field  Name of field to sort by.  Can be <code>null</code> if
*               <code>type</code> is SCORE or DOC.
* @param type   Type of values in the terms.
* @param reverse True if natural order should be reversed.
*/
- (id) initWithField: (NSString *) f type: (LCSortFieldType) t
			 reverse: (BOOL) r
{
	self = [self initWithField: f type: t];
	reverse = r;
	return self;
}

/** Creates a sort by terms in the given field sorted
* according to the given locale.
* @param field  Name of field to sort by, cannot be <code>null</code>.
* @param locale Locale of values in the field.
*/
- (id) initWithField: (NSString *) f locale: (id) l
{
	self = [self initWithField: f];
	ASSIGN(locale, l);
	type = LCSortField_STRING;
	return self;
}

/** Creates a sort, possibly in reverse, by terms in the given field sorted
* according to the given locale.
* @param field  Name of field to sort by, cannot be <code>null</code>.
* @param locale Locale of values in the field.
*/
- (id) initWithField: (NSString *) f locale: (id) l
			 reverse: (BOOL) r
{
	self = [self initWithField: f];
	ASSIGN(locale, l);
	type = LCSortField_STRING;
	reverse = r;
	return self;
}

/** Creates a sort with a custom comparison function.
* @param field Name of field to sort by; cannot be <code>null</code>.
* @param comparator Returns a comparator for sorting hits.
*/
- (id) initWithField: (NSString *) f 
		  comparator: (id) comparator
{
	self = [self initWithField: f type: LCSortField_CUSTOM];
	ASSIGN(factory, comparator);
	return self;
}

/** Creates a sort, possibly in reverse, with a custom comparison function.
* @param field Name of field to sort by; cannot be <code>null</code>.
* @param comparator Returns a comparator for sorting hits.
* @param reverse True if natural order should be reversed.
*/
- (id) initWithField: (NSString *) f 
		  comparator: (id) comparator
			 reverse: (BOOL) r
{
	self = [self initWithField: f comparator: comparator];
	reverse = r;
	return self;
}

- (void) dealloc
{
	DESTROY(field);
	DESTROY(factory);
	DESTROY(locale);
	[super dealloc];
}

/** Returns the name of the field.  Could return <code>null</code>
* if the sort is by SCORE or DOC.
* @return Name of field, possibly <code>null</code>.
*/
- (NSString *) field
{
	return field;
}

/** Returns the type of contents in the field.
* @return One of the constants SCORE, DOC, AUTO, STRING, INT or FLOAT.
*/
- (LCSortFieldType) type
{
	return type;
}

/** Returns the Locale by which term values are interpreted.
* May return <code>null</code> if no Locale was specified.
* @return Locale, or <code>null</code>.
*/
- (id) locale
{
    return locale;
}

/** Returns whether the sort should be reversed.
* @return  True if natural order should be reversed.
*/
- (BOOL) reverse
{
	return reverse;
}

- (id) factory 
{
	return factory;
}

- (NSString *) description
{
	NSMutableString *s = [[NSMutableString alloc] init];
	switch (type)
	{
		case LCSortField_SCORE:
			[s appendString: @"<score>"];
			break;
		case LCSortField_DOC:
			[s appendString: @"<doc>"];
			break;
		case LCSortField_CUSTOM:
			[s appendFormat: @"<custom:\"%@\": %@>", field, factory];
			break;
		default:
			[s appendFormat: @"\"%@\"", field];
			break;
	}
	
	if (locale != nil) [s appendFormat: @"(%@)", locale];
	if (reverse) [s appendString: @"!"];
	
	return AUTORELEASE(s);
}

@end
