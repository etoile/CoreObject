#include "LCTerm.h"
#include "GNUstep.h"

/**
A Term represents a word from text.  This is the unit of search.  It is
 composed of two elements, the text of the word, as a string, and the name of
 the field that the text occured in, an interned string.
 
 Note that terms may represent more than words from text fields, but also
 things like dates, email addresses, urls, etc.  */

@implementation LCTerm

- (id) init
{
  return [self initWithField: [NSString string] text: [NSString string]];
}

/** Constructs a Term with the given field and text. */
- (id) initWithField: (NSString *) fld text: (NSString *) txt
{
	self = [super init];
	ASSIGNCOPY(field, fld);
	ASSIGNCOPY(text, txt);
	return self;
	//  this(fld, txt, true);
}

- (void) dealloc
{
	DESTROY(field);
	DESTROY(text);
	[super dealloc];
}

#if 0
Term(String fld, String txt, boolean intern) {
    field = intern ? fld.intern() : fld;	  // field names are interned
    text = txt;					  // unless already known to be
}
#endif

/** Returns the field of this term, an interned string.   The field indicates
the part of a document which this term came from. */
- (NSString *) field
{
	return field;
}

/** Returns the text of this term.  In the case of words, this is simply the
text of the word.  In the case of dates and other types, this is an
encoding of the object as a string.  */
- (NSString *) text
{
	return text;
}

/** Compares two terms, returning true iff they have the same
field and text. */
- (BOOL) isEqual: (id) o
{
	if (o == nil) return NO;
	return ([self compare: (LCTerm *)o] == NSOrderedSame) ? YES : NO;
}

/** Combines the hashCode() of the field and the text. */
- (NSUInteger) hash
{
	return [field hash] + [text hash];
}

/** Compares two terms, returning a negative integer iff this
term belongs before the argument, zero if this term is equal to the
argument, and a positive integer if this term belongs after the argument.

The ordering of terms is first by field, then by text.*/
- (NSComparisonResult) compare: (LCTerm *) other 
{
/* LuceneKit: NSOrderedDescending match the desired result (pass test units),
 * though I am not sure it is correct.
 */
	if ([other field] == nil) return NSOrderedDescending;
	if ([field isEqualToString: [other field]])	  // fields are interned
	{
		if ([other text] == nil) return NSOrderedDescending;
		return [text compare: [other text]];
	}
	else
		return [field compare: [other field]];
}

/** Resets the field and text of a Term. */
- (void) setField: (NSString *) fld
{
	ASSIGNCOPY(field, fld);
}

- (void) setText: (NSString *) txt
{
	ASSIGNCOPY(text, txt);
}

- (void) setTerm: (LCTerm *) other
{
	[self setField: [other field]];
	[self setText: [other text]];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@:%@", field, text];
}

- (id) copyWithZone: (NSZone *) zone
{
	LCTerm *clone = [[LCTerm allocWithZone: zone] initWithField: [self field] text: [self text]];
	return clone;
}

@end
