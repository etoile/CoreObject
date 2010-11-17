#ifndef __LUCENE_SEARCH_SORT__
#define __LUCENE_SEARCH_SORT__

#include <Foundation/Foundation.h>
#include "LCSortField.h"

@interface LCSort: NSObject // Serializable
{
	NSArray *fields;
}
+ (LCSort *) sort_RELEVANCE;
+ (LCSort *) sort_INDEXORDER;
- (id) initWithField: (NSString *) field;
- (id) initWithField: (NSString *) field reverse: (BOOL) reverse;
- (id) initWithFields: (NSArray *) fields;
- (id) initWithSortField: (LCSortField *) field;
- (id) initWithSortFields: (NSArray *) fields;
- (void) setField: (NSString *) field;
- (void) setField: (NSString *) field reverse: (BOOL) reverse;
- (void) setFields: (NSArray *) fields;
- (void) setSortField: (LCSortField *) field;
- (void) setSortFields: (NSArray *) fields;
- (NSArray *) sortFields;
@end
#endif /* __LUCENE_SEARCH_SORT__ */
