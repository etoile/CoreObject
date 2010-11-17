#ifndef __LUCENE_DOCUMENT_DATE_TOOLS__
#define __LUCENE_DOCUMENT_DATE_TOOLS__

#include <Foundation/Foundation.h>

/** Define the resolution of data to be stored */
typedef enum _LCResolution {
	LCResolution_YEAR = 1,
	LCResolution_MONTH,
	LCResolution_DAY,
	LCResolution_HOUR,
	LCResolution_MINUTE,
	LCResolution_SECOND,
	LCResolution_MILLISECOND
} LCResolution;

/** Convert between NSString and NSCalendarDate */
@interface NSString (LuceneKit_Document_Date)
/** Convert a NSCalendarDate to NSString in GMT with resolution */
+ (id) stringWithCalendarDate: (NSCalendarDate *) date
                   resolution: (LCResolution) resolution;
/** Convert a NSTimeInterval to NSString with resolution */
+ (id) stringWithTimeIntervalSince1970: (NSTimeInterval) time
                            resolution: (LCResolution) resolution;
/** Convert a NSString to NSTimeInterval */
- (NSTimeInterval) timeIntervalSince1970;
/** Convert a NSString in GMT to NSCalendarDate */
- (NSCalendarDate *) calendarDate;
@end

/** NSCalendarData with resolution */
@interface NSCalendarDate (LuceneKit_Document_Date)
/** Convert NSCalendarData to resolution */
- (NSCalendarDate *) dateWithResolution: (LCResolution) resolution;
/** Convert NSTimeInterval to resolution */
- (NSTimeInterval) timeIntervalSince1970WithResolution: (LCResolution) resolution;
@end

#endif /* __LUCENE_DOCUMENT_DATE_TOOLS__ */

