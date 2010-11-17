#ifndef __LUCENE_SEARCH_FIELD_CACHE_IMPL__
#define __LUCENE_SEARCH_FIELD_CACHE_IMPL__

#include "LCSortField.h"
#include "LCFieldCache.h"

@interface LCEntry: NSObject <NSCopying>
{
	NSString *field;
	LCSortFieldType type;
	id custom; // which custom comparator
	id locale; // GNUstep has no NSLocale yet.
}

- (id) initWithField: (NSString *) field
		type: (LCSortFieldType) type
              locale: (id) locale;
- (id) initWithField: (NSString *) field
			  custom: (id) custom;
- (NSString *) field;
- (LCSortFieldType) type;
- (id) custom;
- (id) locale;
- (void) setField: (NSString *) field;
- (void) setType: (LCSortFieldType) type;
- (void) setCustom: (id) custom;
- (void) setLocale: (id) locale;
@end

@interface LCFieldCacheImpl: LCFieldCache
{
	/** The internal cache. Maps Entry to array of interpreted term values. **/
	NSMutableDictionary *cache;
}
- (id) lookup: (LCIndexReader *) reader field: (NSString *) field
		 type: (LCSortFieldType) type
		locale: (id) locale;
- (id) lookup: (LCIndexReader *) reader field: (NSString *) field
	 comparer: (id) comparer;
- (id) store: (LCIndexReader *) reader field: (NSString *) field
		type: (LCSortFieldType) type locale: (id) locale
		custom: (id) value;
- (id) store: (LCIndexReader *) reader field: (NSString *) field
	comparer: (id) comparer custom: (id) value;

@end

#endif /* __LUCENE_SEARCH_FIELD_CACHE_IMPL__ */
