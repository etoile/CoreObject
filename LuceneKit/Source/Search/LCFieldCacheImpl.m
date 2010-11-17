#include "LCFieldCacheImpl.h"
#include "GNUstep.h"

@interface LCIntParserImpl: LCIntParser
@end

@interface LCFloatParserImpl: LCFloatParser
@end

/**
* Expert: The default cache implementation, storing all values in memory.
 * A WeakHashMap is used for storage.
 *
 * <p>Created: May 19, 2004 4:40:36 PM
 *
 * @author  Tim Jones (Nacimiento Software)
 * @since   lucene 1.4
 * @version $Id$
 */
/** Expert: Every key in the internal cache is of this type. */
@implementation LCEntry
- (id) initWithField: (NSString *) f
		type: (LCSortFieldType) t
 	      locale: (id) l
{
	self = [super init];
	ASSIGN(field, f);
	type = t;
	custom = nil;
	locale = l;
	return self;
}

- (id) initWithField: (NSString *) f
			  custom: (id) c
{
	self = [self initWithField: f type: LCSortField_CUSTOM locale: nil];
	ASSIGN(custom, c);
	return self;
}

- (void) dealloc
{
  DESTROY(custom);
  DESTROY(field);
  [super dealloc];
}

- (NSString *) field { return field; }
- (LCSortFieldType) type { return type; }
- (id) custom { return custom; }
- (id) locale { return locale; }
- (void) setField: (NSString *) f { ASSIGN(field, f); }
- (void) setType: (LCSortFieldType) t { type = t; }
- (void) setCustom: (id) c { ASSIGN(custom, c); }
- (void) setLocale: (id) l { ASSIGN(locale, l); }

- (BOOL) isEqual: (id) o
{
	if ([o isKindOfClass: [self class]])
	{
		LCEntry *other = (LCEntry *) o;
		if ([[other field] isEqualToString: field] && ([other type] == type))
		{
			if (([other locale] == nil) ? (locale == nil) : [[other locale] isEqual: locale]) {
			if (([other custom] == nil) && (custom == nil))
			{
				return YES;
			}
			else if ([[other custom] isEqual: custom])
			{
				return YES;
			}
			}
		}
	}
	return NO;
}

- (NSUInteger) hash
{
	return [field hash] ^ type ^ ((custom == nil) ? 0 : [custom hash]) ^ ((locale == nil) ? 0 : [locale hash]);
}

- (id) copyWithZone: (NSZone *) zone
{
	LCEntry *entry = [[LCEntry allocWithZone: zone] initWithField: AUTORELEASE([[self field] copy]) type: [self type] locale: [self locale]];
	[entry setCustom: [self custom]];
	return entry;
}

@end

/** Indicator for StringIndex values in the cache. */
// NOTE: the value assigned to this constant must not be
// the same as any of those in SortField!!
//
static int LCFieldCache_STRING_INDEX = -1;

@implementation LCFieldCacheImpl

- (id) init
{
	self = [super init];
	cache = [[NSMutableDictionary alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(cache);
	[super dealloc];
}

/** See if an object is in the cache. */
- (id) lookup: (LCIndexReader *) reader field: (NSString *) field
		 type: (LCSortFieldType) type
	locale: (id) locale
{
  LCEntry *entry = AUTORELEASE([[LCEntry alloc] initWithField: field type: type locale: locale]);
	//    synchronized (this) {
	NSDictionary *readerCache = [cache objectForKey: reader];
	if (readerCache == nil) return nil;
	return [readerCache objectForKey: entry];
	//    }
}

/** See if a custom object is in the cache. */
- (id) lookup: (LCIndexReader *) reader field: (NSString *) field
	 comparer: (id) comparer
{
  LCEntry *entry = AUTORELEASE([[LCEntry alloc] initWithField: field custom: comparer]);
	//    synchronized (this) {
	NSDictionary *readerCache = [cache objectForKey: reader];
	if (readerCache == nil) return nil;
	return [readerCache objectForKey: entry];
	//    }
}

/** Put an object into the cache. */
- (id) store: (LCIndexReader *) reader field: (NSString *) field
		type: (LCSortFieldType) type locale: (id) locale
		custom: (id) value
{
  LCEntry *entry = AUTORELEASE([[LCEntry alloc] initWithField: field type: type locale: locale]);
	//    synchronized (this) {
	NSMutableDictionary *readerCache = [cache objectForKey: reader];
	if (readerCache == nil)
	{
		readerCache = [[NSMutableDictionary alloc] init];
		AUTORELEASE(readerCache);
	}
	[readerCache setObject: value forKey: entry];
	[cache setObject: readerCache forKey: reader];
	return readerCache;
	//    }
}

/** Put a custom object into the cache. */
- (id) store: (LCIndexReader *) reader field: (NSString *) field
	comparer: (id) comparer custom: (id) value
{
  LCEntry *entry = AUTORELEASE([[LCEntry alloc] initWithField: field custom: comparer]);
	//    synchronized (this) {
	NSMutableDictionary *readerCache = [cache objectForKey: reader];
	if (readerCache == nil)
	{
		readerCache = [[NSMutableDictionary alloc] init];
		AUTORELEASE(readerCache);
	}
	[readerCache setObject: value forKey: entry];
	[cache setObject: readerCache forKey: reader];
	return readerCache;
	//    }
}

- (NSDictionary *) ints: (LCIndexReader *) reader field: (NSString *) field
{
	return [self ints: reader field: field parser: AUTORELEASE([[LCIntParserImpl alloc] init])];
}

- (NSDictionary *) ints: (LCIndexReader *) reader field: (NSString *) field
		   parser: (LCIntParser *) parser
{
	id ret = [self lookup: reader field: field comparer: parser];
	if (ret == nil) {
          NSMutableDictionary *retDic = AUTORELEASE([[NSMutableDictionary alloc] init]);
		id <LCTermDocuments> termDocs = [reader termDocuments];
		LCTerm *t = AUTORELEASE([[LCTerm alloc] initWithField: field text: @""]);
		LCTermEnumerator *termEnum = [reader termEnumeratorWithTerm: t];
		do {
			LCTerm *term = [termEnum term];
			if (term == nil || [[term field] isEqualToString: field] == NO) break;
			int termval = [parser parseInt: [term text]];
			[termDocs seekTermEnumerator: termEnum];
			while ([termDocs hasNextDocument]) {
				[retDic setObject: [NSNumber numberWithInt: termval]
						   forKey: [NSNumber numberWithInt: [termDocs document]]];
			}
		} while ([termEnum hasNextTerm]);
		[termDocs close];
		[termEnum close];
		[self store: reader field: field comparer: parser custom: retDic];
		return retDic;
	}
	return ret;
}

- (NSDictionary *) floats: (LCIndexReader *) reader field: (NSString *) field
{
	return [self floats: reader field: field parser: AUTORELEASE([[LCFloatParserImpl alloc] init])];
}

- (NSDictionary *) floats: (LCIndexReader *) reader field: (NSString *) field
		parser: (LCFloatParser *) parser
{
	id ret = [self lookup: reader field: field comparer: parser];
	if (ret == nil) {
          NSMutableDictionary *retDic = AUTORELEASE([[NSMutableDictionary alloc] init]);
		id <LCTermDocuments> termDocs = [reader termDocuments];
		LCTerm *t = AUTORELEASE([[LCTerm alloc] initWithField: field text: @""]);
		LCTermEnumerator *termEnum = [reader termEnumeratorWithTerm: t];

		do {
			LCTerm *term = [termEnum term];
			if (term == nil || [[term field] isEqualToString: field] == NO) break;
			float termval = [parser parseFloat: [term text]];
			[termDocs seekTermEnumerator: termEnum];
			while ([termDocs hasNextDocument]) {
				[retDic setObject: [NSNumber numberWithFloat: termval]
						   forKey: [NSNumber numberWithInt: [termDocs document]]];
			}
		} while ([termEnum hasNextTerm]);
		[termDocs close];
		[termEnum close];
		[self store: reader field: field comparer: parser custom: retDic];
		return retDic;
	}
	return ret;
}

- (NSDictionary *) strings: (LCIndexReader *) reader field: (NSString *) field
{
	id ret = [self lookup: reader field: field type: LCSortField_STRING locale: nil];
	if (ret == nil) {
          NSMutableDictionary *retDic = AUTORELEASE([[NSMutableDictionary alloc] init]);
		id <LCTermDocuments> termDocs = [reader termDocuments];
		LCTerm *t = AUTORELEASE([[LCTerm alloc] initWithField: field text: @""]);
		LCTermEnumerator *termEnum = [reader termEnumeratorWithTerm: t];

		do {
			LCTerm *term = [termEnum term];
			if (term == nil || [[term field] isEqualToString: field] == NO) break;
			NSString *termval = [[term text] copy];
			[termDocs seekTermEnumerator: termEnum];
			while ([termDocs hasNextDocument]) {
				[retDic setObject: AUTORELEASE(termval)
						   forKey: [NSNumber numberWithInt: [termDocs document]]];
			}
		} while ([termEnum hasNextTerm]);
		[termDocs close];
		[termEnum close];
		[self store: reader field: field type: LCSortField_STRING locale: nil custom: retDic];
		return retDic;
	}
	return ret;
}

- (LCStringIndex *) stringIndex: (LCIndexReader *) reader
						  field: (NSString *) field
{
	id ret = [self lookup: reader field: field type: LCFieldCache_STRING_INDEX locale: nil];
	if (ret == nil) {
          NSMutableDictionary *retDic = AUTORELEASE([[NSMutableDictionary alloc] init]);
          NSMutableArray *mterms = AUTORELEASE([[NSMutableArray alloc] init]);
#if 0
		final int[] retArray = new int[reader.maxDoc()];
		String[] mterms = new String[reader.maxDoc()+1];
#endif
		id <LCTermDocuments> termDocs = [reader termDocuments];
		LCTerm *tm = [[LCTerm alloc] initWithField: field text: @""];
		LCTermEnumerator *termEnum = [reader termEnumeratorWithTerm: tm];
		RELEASE(tm);
		int t = 0;  // current term number
			
		// an entry for documents that have no terms in this field
		// should a document with no terms be at top or bottom?
		// this puts them at the top - if it is changed, FieldDocSortedHitQueue
		// needs to change as well.
		/* LuceneKit: insert a non-NSString object */
		//[mterms addObject: AUTORELEASE([[NSObject alloc] init])];
		[mterms addObject: [NSNull null]];

			
		do {
			LCTerm *term = [termEnum term];
			if (term == nil || [[term field] isEqualToString: field] == NO) break;
				
			// store term text
			// we expect that there is at most one term per document
			//    if (t >= mterms.length) throw new RuntimeException ("there are more terms than documents in field \"" + field + "\"");
			[mterms addObject: AUTORELEASE([term text])];//FIXME Why autoreleasing it ?
			
			[termDocs seekTermEnumerator: termEnum];
			while ([termDocs hasNextDocument]) {
				[retDic setObject: [NSNumber numberWithInt: t]
						   forKey: [NSNumber numberWithInt: [termDocs document]]];
			}
				
			t++;
		} while ([termEnum hasNextTerm]);
		[termDocs close];
		[termEnum close];
			
		if (t == 0) {
			// if there are no terms, make the term array
			// have a single null entry
			/* LuceneKit: This is not going to happend */
			[mterms addObject: [NSNull null]];
		} else if (t < [reader maximalDocument]+1) {
			// if there are less terms than documents,
			// trim off the dead array space
			/* LuceneKit: not necessary
			String[] terms = new String[t];
			System.arraycopy (mterms, 0, terms, 0, t);
			mterms = terms;
			*/
		}
		LCStringIndex *value = [[LCStringIndex alloc] initWithOrder: retDic
															 lookup: mterms];
		[self store: reader field: field type: LCFieldCache_STRING_INDEX
			 locale: nil custom: value];
		return AUTORELEASE(value);
	}
	return ret;
}

/** The pattern used to detect integer values in a field */
/** removed for java 1.3 compatibility
protected static final Pattern pIntegers = Pattern.compile ("[0-9\\-]+");
**/

/** The pattern used to detect float values in a field */
/**
* removed for java 1.3 compatibility
 * protected static final Object pFloats = Pattern.compile ("[0-9+\\-\\.eEfFdD]+");
 */

- (id) objects: (LCIndexReader *) reader field: (NSString *) field
{
	id ret = [self lookup: reader field: field type: LCSortField_AUTO locale: nil];
	if (ret == nil) {
          LCTerm *t = AUTORELEASE([[LCTerm alloc] initWithField: field text: @""]);
		LCTermEnumerator *enumerator = [reader termEnumeratorWithTerm: t];
		LCTerm *term = [enumerator term];
		if (term == nil) {
			NSLog(@"No terms in field %@ - cannot determin sort type", field);
			return nil;
		}
		if ([[term field] isEqualToString: field]) {
			NSString *termtext = [[term text] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			
			/**
			* Java 1.4 level code:
			 
			 if (pIntegers.matcher(termtext).matches())
			 return IntegerSortedHitQueue.comparator (reader, enumerator, field);
			 
			 else if (pFloats.matcher(termtext).matches())
			 return FloatSortedHitQueue.comparator (reader, enumerator, field);
			 */
			
			// Java 1.3 level code:
			/* May not be accurate */
			int test_int = [termtext intValue];
			/* FIXME */
			if (test_int != 0)
			{
				ret = [self ints: reader field: field];
			}
			else 
			{
				float test_float = [termtext floatValue];
				/* FIXME */
				if (test_float != 0.0)
				{
					ret = [self floats: reader field: field];
				}
				else
				{
					ret = [self stringIndex: reader field: field];
				}
			}
			if (ret != nil) {
				[self store: reader field: field type: LCSortField_AUTO locale: nil custom: ret];
			}
		} else {
			NSLog(@"field \"%@\" does not apper to be indexed", field);
			return nil;
		}
		[enumerator close];
	}
	return ret;
}

// inherit javadocs
- (NSDictionary *) custom: (LCIndexReader *) reader field: (NSString *) field
		   sortComparator: (LCSortComparator *) comparator
{
	id ret = [self lookup: reader field: field comparer: comparator];
	if (ret == nil) {
          NSMutableDictionary *retDic = AUTORELEASE([[NSMutableDictionary alloc] init]);
		id <LCTermDocuments> termDocs = [reader termDocuments];
		LCTerm *t = AUTORELEASE([[LCTerm alloc] initWithField: field text: @""]);
		LCTermEnumerator *termEnum = [reader termEnumeratorWithTerm: t];

		do {
			LCTerm *term = [termEnum term];
			if (term == nil || [[term field] isEqualToString: field] == NO) break;
			id termval = [comparator comparable: [term text]];
			[termDocs seekTermEnumerator: termEnum];
			while ([termDocs hasNextDocument]) {
				[retDic setObject: termval 
					   forKey: [NSNumber numberWithInt: [termDocs document]]];
			}
		} while ([termEnum hasNextTerm]);
		[termDocs close];
		[termEnum close];
		[self store: reader field: field comparer: comparator custom: retDic];
		return retDic;
	}
	return ret;
}

@end

@implementation LCIntParserImpl

- (int) parseInt: (NSString *) value
{
	return [value intValue];
}

@end

@implementation LCFloatParserImpl

- (float) parseFloat: (NSString *) value
{
	return [value floatValue];
}

@end
