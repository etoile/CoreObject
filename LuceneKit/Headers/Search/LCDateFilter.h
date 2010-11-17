#ifndef __LUCENE_SEARCH_DATE_FILTLER__
#define __LUCENE_SEARCH_DATE_FILTLER__

#include "LCFilter.h"

@class LCBitVector;
@class LCIndexReader;

@interface LCDateFilter: LCFilter
{
	NSString *field;
	NSString *start;
	NSString *end;
}

- (id) initWithString: (NSString *) filter;
- (id) initWithString: (NSString *) filter
				 from: (NSCalendarDate *) from
				   to: (NSCalendarDate *) to;
- (id) initWithString: (NSString *) filter
	 fromTimeInterval: (NSTimeInterval) from
       toTimeInterval: (NSTimeInterval) to;
+ (LCDateFilter *) before: (NSString *) field date: (NSCalendarDate *) date;
+ (LCDateFilter *) before: (NSString *) field timeInterval: (NSTimeInterval) time;
+ (LCDateFilter *) after: (NSString *) field date: (NSCalendarDate *) date;
+ (LCDateFilter *) after: (NSString *) field timeInterval: (NSTimeInterval) time;
- (LCBitVector *) bits: (LCIndexReader *) reader;
@end

#endif /* __LUCENE_SEARCH_DATE_FILTLER__ */
